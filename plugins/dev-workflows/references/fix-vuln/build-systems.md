# Build Systems - Dependency Detection & Update Patterns

## Detection order

Inspect the repo root (and common subdirectories) for these indicator files in priority order:

| File | Ecosystem |
|---|---|
| `build.gradle` or `build.gradle.kts` | Gradle (Java/Kotlin) |
| `pom.xml` | Maven (Java) |
| `package.json` | Node.js / npm / yarn |
| `requirements.txt`, `Pipfile`, `pyproject.toml` | Python / pip |
| `go.mod` | Go modules |
| `*.csproj` or `*.sln` | .NET / NuGet |
| `Gemfile` | Ruby / Bundler |
| `Cargo.toml` | Rust / Cargo |

Multiple ecosystems may coexist (e.g., a Java backend + npm frontend). Check all of them.

---

## Gradle

### Detect library

Search for the artifact ID in all `*.gradle` and `*.gradle.kts` files:

```bash
grep -r "activemq" . --include="*.gradle" --include="*.gradle.kts" -l
```

Also check `gradle.properties` for version variables:

```bash
grep -r "activemq" gradle.properties
```

### Version sources (in priority order)

1. **Version catalog** (`gradle/libs.versions.toml`) - preferred for multi-project builds
2. **`gradle.properties`** - version variables referenced as `${activemqVersion}`
3. **Inline in `build.gradle`** - `implementation "org.apache.activemq:activemq-all:5.16.6"`

### Update

- **Version catalog**: edit `[versions]` section in `gradle/libs.versions.toml`
- **gradle.properties**: update the property value
- **Inline**: update the version string in the dependency declaration

### Verify build

```bash
./gradlew build -x test    # build without tests first
./gradlew test             # then run tests
```

For a single module: `./gradlew :<module>:test`

---

## Maven

### Detect library

```bash
grep -r "activemq" . --include="pom.xml" -l
```

### Version sources

1. `<dependencyManagement>` section in parent `pom.xml`
2. `<properties>` section: `<activemq.version>5.16.6</activemq.version>`
3. Inline `<version>` in the `<dependency>` block

### Update

Edit the version in the appropriate `pom.xml`. Prefer updating `<properties>` to keep it in one place.

### Verify build

```bash
mvn package -DskipTests    # build first
mvn test                   # then test
```

---

## npm / yarn / pnpm

### Detect library

```bash
grep -r "\"activemq\"" package.json
```

Also check `package-lock.json` or `yarn.lock` for transitive dependencies.

### Distinguish direct vs. transitive

- **Direct** (in `package.json` `dependencies`/`devDependencies`): update `package.json` version constraint and run `npm install`.
- **Transitive only**: use `overrides` (npm 8.3+) or `resolutions` (yarn) in `package.json`.

### Update direct dependency

```bash
npm install <package>@<safe-version>
```

Or edit `package.json` manually and run `npm install`.

### Override transitive dependency

```json
// package.json
"overrides": {
  "<package>": "<safe-version>"
}
```

### Verify

```bash
npm test
```

---

## Python (pip)

### Detect library

```bash
grep -ri "requests" requirements.txt Pipfile pyproject.toml
```

### Update

- **`requirements.txt`**: change `requests==2.28.0` to `requests==<safe-version>` (use `==` for pinned, `>=` for minimum).
- **`Pipfile`**: edit `[packages]` section and run `pipenv install`.
- **`pyproject.toml`**: edit `[project.dependencies]` or `[tool.poetry.dependencies]`.

### Verify

```bash
pip install -r requirements.txt
pytest                     # or python -m pytest
```

---

## Go modules

### Detect library

```bash
grep "activemq" go.mod go.sum
```

### Update

```bash
go get <module>@<safe-version>
go mod tidy
```

### Verify

```bash
go build ./...
go test ./...
```

---

## .NET / NuGet

### Detect library

```bash
grep -r "ActiveMQ" . --include="*.csproj" -l
```

### Update

```bash
dotnet add package <PackageName> --version <safe-version>
```

Or edit `<PackageReference Include="..." Version="...">` in the `.csproj` file.

### Verify

```bash
dotnet build
dotnet test
```

---

## Ruby / Bundler

### Detect library

```bash
grep -i "<gem_name>" Gemfile Gemfile.lock
```

### Version sources

1. `Gemfile` — `gem '<name>', '~> x.y'` or `gem '<name>', '>= x.y.z'`
2. `Gemfile.lock` — pinned resolved version

### Update

Edit the version constraint in `Gemfile`, then:

```bash
bundle update <gem_name>
```

Or to update only to the minimum safe version:

```bash
bundle update <gem_name> --conservative
```

### Override transitive gem

If the vulnerable gem is a transitive dependency, add an explicit constraint to `Gemfile`:

```ruby
# Gemfile — force safe version of a transitive dependency
gem '<gem_name>', '>= <safe-version>'
```

Then run `bundle update <gem_name>`.

### Verify

```bash
bundle exec rspec          # or rake test / bundle exec minitest
```

---

## Transitive dependency strategy

When the vulnerable library is **not** a direct dependency but pulled in transitively:

1. Identify which direct dependency introduces it (using `./gradlew dependencies`, `mvn dependency:tree`, `npm ls`, etc.).
2. **First choice**: upgrade the direct dependency to a version that already uses the safe transitive version.
3. **Second choice**: force/override the transitive version using the ecosystem mechanism (Gradle `resolutionStrategy`, Maven `dependencyManagement`, npm `overrides`, etc.).
4. Document the override clearly in the commit message.

## Confirming the fix

After updating, verify the vulnerable version is no longer on the classpath/bundle:

```bash
# Gradle
./gradlew dependencies | grep activemq

# Maven
mvn dependency:tree | grep activemq

# npm
npm ls <package>

# Go
go list -m all | grep <module>
```
