# Ecosystems — Detection, Update Commands & Registry Queries

## Detection order

Scan the repo root (and common subdirectory structures) for these indicator files:

| Indicator file(s) | Ecosystem | Build tool |
|---|---|---|
| `build.gradle` / `build.gradle.kts` | Java / Kotlin | Gradle |
| `pom.xml` | Java / Kotlin / Scala | Maven |
| `gradlew` + `gradle/wrapper/gradle-wrapper.properties` | Gradle wrapper itself | — |
| `package.json` | Node.js | npm / yarn / pnpm |
| `pyproject.toml` / `requirements.txt` / `Pipfile` | Python | pip / poetry / pipenv |
| `go.mod` | Go | Go modules |
| `*.csproj` / `*.sln` / `global.json` | .NET | dotnet CLI |
| `Gemfile` | Ruby | Bundler |
| `Cargo.toml` | Rust | Cargo |
| `composer.json` | PHP | Composer |
| `Dockerfile` / `*.dockerfile` | Container base image | Docker |
| `.github/workflows/*.yml` | GitHub Actions | gh CLI / REST API |

Multiple ecosystems can coexist. Detect all of them and handle each independently.

---

## Gradle (Java / Kotlin / Groovy)

### Detecting a dependency

```bash
# Grep across all build files
grep -r "<artifactId_or_groupId>" . --include="*.gradle" --include="*.gradle.kts" --include="gradle.properties" --include="libs.versions.toml"
```

### Version locations (priority order)

1. `gradle/libs.versions.toml` — version catalog (`[versions]` table)
2. `gradle.properties` — version variables (e.g. `springBootVersion=3.1.4`)
3. Inline in `build.gradle` / `build.gradle.kts`

### Upgrading Spring Boot (Gradle)

Edit the `plugins {}` block version or the version variable:
```groovy
// build.gradle
id 'org.springframework.boot' version '3.3.11'
```
```toml
# libs.versions.toml
spring-boot = "3.3.11"
```

### Upgrading Gradle wrapper

```bash
./gradlew wrapper --gradle-version=<target> --distribution-type=bin
# Verify
./gradlew --version
```

### Query Maven Central for available versions

```
GET https://search.maven.org/solrsearch/select?q=g:<groupId>+AND+a:<artifactId>&core=gav&rows=50&wt=json
```

Response: `.response.docs[].v` lists all versions. Filter to stable (no `-SNAPSHOT`, `-alpha`, `-beta`, `-rc`).

### Build & test

```bash
./gradlew build -x test   # compile + assemble
./gradlew test             # run tests
./gradlew :<module>:test   # single module
```

---

## Maven (Java / Kotlin)

### Version locations

1. `<properties>` in `pom.xml` (e.g. `<spring-boot.version>3.1.4</spring-boot.version>`)
2. `<dependencyManagement>` / `<pluginManagement>` sections
3. Inline `<version>` in `<dependency>` blocks

### Upgrading Spring Boot (Maven)

Update the parent POM version:
```xml
<parent>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-parent</artifactId>
  <version>3.3.11</version>
</parent>
```
Or the `spring-boot.version` property if using the BOM without a parent.

### Build & test

```bash
mvn package -DskipTests
mvn test
```

---

## npm / yarn / pnpm (Node.js)

### Detecting a package

```bash
grep '"<package>"' package.json
npm ls <package> 2>/dev/null | head -5
```

### Upgrading

```bash
npm install <package>@<version>           # direct dependency
npm install                               # refresh lock file
```

For transitive overrides:
```json
// package.json
"overrides": { "<package>": "<version>" }
```

### Querying npm registry

```
GET https://registry.npmjs.org/<package>
```
- `.dist-tags.latest` — latest stable
- `.versions` keys — all published versions

### Build & test

```bash
npm run build   # if build script exists
npm test
```

---

## Python (pip / poetry / pipenv)

### Detecting a package

```bash
grep -i "<package>" requirements.txt Pipfile pyproject.toml setup.cfg
```

### Upgrading

- **requirements.txt**: edit the pinned version, then `pip install -r requirements.txt`
- **poetry**: `poetry add <package>@<version>` or edit `pyproject.toml` then `poetry lock --no-update` then `poetry install`
- **pipenv**: `pipenv install <package>==<version>`

### Querying PyPI

```
GET https://pypi.org/pypi/<package>/json
```
- `.info.version` — latest stable
- `.releases` keys — all versions

### Build & test

```bash
pytest           # or python -m pytest
python -m pytest tests/
```

---

## Go modules

### Detecting a module

```bash
grep "<module>" go.mod
```

### Upgrading

```bash
go get <module>@<version>
go mod tidy
```

### Querying Go proxy

```
GET https://proxy.golang.org/<module>/@v/list   # all known versions
GET https://proxy.golang.org/<module>/@latest   # latest
```

### Build & test

```bash
go build ./...
go test ./...
```

---

## .NET / NuGet

### Detecting a package

```bash
grep -r "<PackageName>" . --include="*.csproj"
```

### Upgrading

```bash
dotnet add package <PackageName> --version <version>
# Or edit <PackageReference Version="..."> directly
```

### Querying NuGet

```
GET https://api.nuget.org/v3-flatcontainer/<package_lower>/index.json
```
`.versions` — list of all versions (last is latest stable).

### SDK / runtime version

Edit `global.json`:
```json
{ "sdk": { "version": "8.0.400" } }
```

### Build & test

```bash
dotnet build
dotnet test
```

---

## Ruby / Bundler

### Detecting a gem

```bash
grep "<gem>" Gemfile Gemfile.lock
```

### Upgrading

```bash
bundle update <gem>
# or edit Gemfile version constraint and run:
bundle install
```

### Querying RubyGems

```
GET https://rubygems.org/api/v1/versions/<gem>.json
```

### Build & test

```bash
bundle exec rspec
# or rake test
```

---

## Rust / Cargo

### Detecting a crate

```bash
grep "<crate>" Cargo.toml
```

### Upgrading

```bash
cargo update -p <crate> --precise <version>
# Or edit Cargo.toml version field
```

### Querying crates.io

```
GET https://crates.io/api/v1/crates/<crate>
```
`.crate.max_stable_version` — latest stable.

### Build & test

```bash
cargo build
cargo test
```

---

## PHP / Composer

### Detecting a package

```bash
grep -i '"<package>"' composer.json
composer show <package> 2>/dev/null | head -5
```

### Upgrading

```bash
composer require <package>:<version>        # direct dependency, exact
composer require "<package>:^<version>"     # allow patch/minor updates
composer update <package>                   # update within constraint
```

Or edit `composer.json` manually and run:

```bash
composer update <package>
```

### Querying Packagist

```
GET https://packagist.org/packages/<vendor>/<package>.json
```
- `.package.versions` — all published versions (filter stable: no `dev-*`, `-alpha`, `-beta`, `-RC`)

### Build & test

```bash
composer install
vendor/bin/phpunit        # or php artisan test for Laravel
```

---

## Docker base images

### Detecting

```bash
grep "^FROM" Dockerfile
```

### Upgrading

Edit the `FROM` line. For official images, check Docker Hub tags:
```
GET https://hub.docker.com/v2/repositories/library/<image>/tags?page_size=50&ordering=last_updated
```

For non-library images: `https://hub.docker.com/v2/repositories/<org>/<image>/tags`

### Validation

```bash
docker build -t test-image . --no-cache
```

---

## GitHub Actions (`.github/workflows`)

### Detecting action references

Scan `uses:` lines:
```bash
grep -r "uses:" .github/workflows/
```

Pattern: `uses: owner/repo@ref` or `uses: owner/repo/subdir@ref`

### Resolving latest release

```bash
gh api repos/<owner>/<repo>/releases/latest --jq .tag_name
# Falls back to:
gh api repos/<owner>/<repo>/tags --jq '.[0].name'
```

Or via REST:
```
GET https://api.github.com/repos/<owner>/<repo>/releases/latest
```

### Updating

Replace `@oldref` with `@newref` in the workflow YAML file.

If pinned to a SHA (`uses: actions/checkout@abc1234`), also update the SHA to the commit at the new tag:
```bash
git ls-remote https://github.com/<owner>/<repo>.git refs/tags/<tag>
```

### Validation

Validate YAML syntax after changes:
```bash
# If actionlint is available:
actionlint .github/workflows/*.yml
# Otherwise just check YAML parse:
python -c "import yaml, sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]" .github/workflows/*.yml
```

---

## Java runtime / JDK version

### Detection

Look for Java version declarations in:
- `build.gradle` / `build.gradle.kts`: `sourceCompatibility`, `targetCompatibility`, `java { toolchain { languageVersion } }`
- `pom.xml`: `<maven.compiler.source>`, `<maven.compiler.target>`, `<java.version>`
- `.java-version` (jenv), `.tool-versions` (asdf), `.sdkmanrc` (SDKMAN)
- `Dockerfile`: `FROM eclipse-temurin:XX` or `FROM amazoncorretto:XX`
- GitHub Actions: `java-version:` in `actions/setup-java` steps

### Upgrading

Update all version declarations consistently. When changing Java major version (e.g. 17 → 21):
- Update `sourceCompatibility` / `targetCompatibility` in build files
- Update `.sdkmanrc`, `.java-version`, `.tool-versions` if present
- Update `Dockerfile` base image tags
- Update `java-version` in GitHub Actions workflows
- Check for and resolve any deprecated APIs (run `./gradlew compileJava` or `mvn compile` and inspect warnings)

---

## Node.js runtime version

### Detection

- `package.json` `engines.node` field
- `.nvmrc`, `.node-version`, `.tool-versions`
- `Dockerfile` `FROM node:XX`
- GitHub Actions: `node-version:` in `actions/setup-node` steps

### Upgrading

Update all declarations consistently (same files as above).

---

## Spring Boot companion upgrades

When upgrading Spring Boot, also check and upgrade these companions to versions compatible with the new Spring Boot release:

| Companion | How to find compatible version |
|---|---|
| Spring Framework | Managed by Spring Boot BOM — usually no manual change needed |
| Hibernate | Check Spring Boot's `spring-boot-dependencies` BOM for the version it manages |
| Mockito | Check Spring Boot's test starter managed version |
| JUnit | Managed by Spring Boot |
| Flyway / Liquibase | May need explicit upgrade for major Spring Boot jumps |
| Spring Security | Major version jumps may require config changes |

Check the Spring Boot migration guide for the target version:
```
https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-<X.Y>-Migration-Guide
```
