# Compatibility Reference

This file documents known compatibility constraints between common components and explains how to look them up dynamically. Always prefer dynamic lookup over hard-coded tables — release schedules move fast.

---

## How to look up compatibility dynamically

### Gradle ↔ Java

**Official matrix:**
```
web_fetch https://docs.gradle.org/current/userguide/compatibility.html
```
The table lists the minimum and maximum Java version supported by each Gradle release.

Key rules (as of early 2025 — always verify against the live page):
- Gradle 8.x supports Java 8–23
- Gradle 9.x requires Java 17 minimum
- Gradle 7.x supports Java 8–19

### Gradle ↔ Spring Boot

Spring Boot's Gradle plugin has a minimum Gradle version requirement documented in each release's reference:
```
web_fetch https://docs.spring.io/spring-boot/docs/current/reference/html/build-tool-plugins.html#build-tool-plugins.gradle
```
Or for a specific version, substitute the version in the URL, e.g.:
```
web_fetch https://docs.spring.io/spring-boot/docs/3.3.0/reference/html/build-tool-plugins.html
```

### Spring Boot ↔ Java

```
web_fetch https://spring.io/projects/spring-boot#support
```
Or check the Spring Boot wiki:
```
web_fetch https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-3.x-Release-Notes
```

Key rules (verify against live docs):
- Spring Boot 3.x requires Java 17 minimum
- Spring Boot 2.7.x supports Java 8–19
- Spring Boot 2.6.x supports Java 8–17

### Spring Boot ↔ Spring Framework

Spring Boot manages the Spring Framework version via its BOM. Do not set Spring Framework version manually unless you have a specific reason. Check the BOM for the exact version:
```
web_fetch https://repo1.maven.org/maven2/org/springframework/boot/spring-boot-dependencies/<version>/spring-boot-dependencies-<version>.pom
```
Search for `spring-framework.version` in the POM.

### Maven ↔ Java

```
web_fetch https://maven.apache.org/docs/history.html
```
Maven 3.9.x supports Java 8+. Maven 4.x requires Java 11+.

### Node.js ↔ npm

npm is bundled with Node.js. The compatible npm version is listed in:
```
GET https://nodejs.org/dist/index.json
```
Each entry has a `npm` field. No manual matching needed — `npm` upgrades automatically with Node.

### Node.js ↔ framework (e.g. Next.js, NestJS, Express)

Check the framework's `package.json` `engines.node` field on npm:
```
GET https://registry.npmjs.org/<framework>/latest
```
Field: `.engines.node` — contains the semver range of supported Node versions.

### Python ↔ library

Most Python packages declare supported Python versions in their metadata:
```
GET https://pypi.org/pypi/<package>/<version>/json
```
Field: `.info.requires_python` — semver range (e.g. `>=3.8`).

### .NET SDK ↔ runtime

The .NET SDK and runtime version compatibility matrix:
```
web_fetch https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core
```

### Go ↔ module

Go modules declare minimum Go version in `go.mod` (`go 1.21`). Check a module's minimum Go:
```
GET https://proxy.golang.org/<module>/@latest
```
Response includes `.GoVersion`.

### Docker base image ↔ application

For official images, the tag schema encodes the runtime version (e.g. `eclipse-temurin:21-jre`). Always match the Docker base image Java/Node/Python version to the version declared in the build files.

---

## General compatibility lookup strategy

For any component pair not covered above:

1. Check the component's **official documentation** or **release notes** for a compatibility or requirements section. Use `web_fetch` on the docs URL.
2. Check **GitHub releases** for breaking change notes: `https://github.com/<org>/<repo>/releases`
3. Check the **Maven Central POM** (for JVM libraries) for transitive dependency versions — these reveal what other libraries a given version was built against.
4. Check **endoflife.date** for EOL status: `https://endoflife.date/api/<product>.json`

---

## Known major migrations

### Spring Boot 2.x → 3.x: `javax.*` → `jakarta.*` namespace migration

Spring Boot 3.0 dropped all `javax.*` packages in favour of `jakarta.*` (Jakarta EE 9+). This affects the entire codebase — every import of a `javax.*` API must be updated.

**Affected namespaces** (non-exhaustive): `javax.servlet`, `javax.persistence`, `javax.validation`, `javax.jms`, `javax.ws.rs` (JAX-RS), `javax.mail`, `javax.annotation`, `javax.inject`, `javax.transaction`.

**Detection:**
```bash
grep -rE "import javax\.(servlet|persistence|validation|jms|ws|mail|annotation|inject|transaction)" src/
```

**Fix:** Bulk rename via IDE refactor or:
```bash
find src/ -name "*.java" -exec sed -i 's/import javax\./import jakarta\./g' {} +
```
Also update Maven/Gradle BOM imports (`javax.persistence:javax.persistence-api` → `jakarta.persistence:jakarta.persistence-api`, etc.).

**Companion changes that commonly surface:**
- Hibernate 5 → 6: uses `jakarta.persistence` (not `javax.persistence`)
- Spring Security 5 → 6: uses `jakarta.servlet` (not `javax.servlet`)
- `javax.annotation.PostConstruct` / `PreDestroy` → `jakarta.annotation.*`
- Deployment descriptors (`web.xml`) referencing `javax.*` schemas need updating
- Third-party libraries still on `javax.*` need replacement versions that ship `jakarta.*`

**Reference:** [Spring Boot 3.0 Migration Guide](https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-3.0-Migration-Guide)

---

## Worked example: `upgrade: gradle` with Java 11 and Spring Boot 2.7 in the repo

1. Fetch all Gradle stable versions from `https://services.gradle.org/versions/all`.
2. Fetch Gradle ↔ Java compatibility from `https://docs.gradle.org/current/userguide/compatibility.html`.
3. Fetch Spring Boot 2.7 Gradle plugin minimum version from Spring Boot docs.
4. Filter Gradle versions to those that:
   - Support Java 11 (rules out Gradle 9+)
   - Meet Spring Boot 2.7's minimum Gradle requirement
5. Select the highest passing version (e.g. Gradle 8.13).
6. Report: "Upgrading Gradle to 8.13 (latest compatible with Java 11 and Spring Boot 2.7). Gradle 9+ requires Java 17+."

---

## Worked example: `upgrade: gradle:9 java:latest` (explicit conflict)

1. Resolve `java:latest` → Java 24 (as of 2025).
2. Resolve `gradle:9` → Gradle 9.x.
3. Check Gradle 9 ↔ Java 24: compatible (Gradle 9 supports Java 17+).
4. Check Java 24 ↔ Spring Boot 2.7 (existing in repo): Spring Boot 2.7 does not support Java 24.
5. **Conflict detected.** Present options:
   - **Option A** (least invasive): Keep `gradle:9`, but cap Java at the highest version supported by Spring Boot 2.7 (Java 19). Upgrade to `java:19` instead.
   - **Option B** (more invasive): Also upgrade Spring Boot to 3.3 (supports Java 21+), then use `java:21` (LTS). This requires a Spring Boot major version migration.
   - **Option C**: Skip `java:latest`, only upgrade Gradle to 9 (Java stays at 11 — verify Gradle 9 supports Java 11, otherwise suggest Gradle 8.13).

---

## Version range query URLs by ecosystem

| Ecosystem | URL to list all versions |
|---|---|
| Maven / Gradle | `https://search.maven.org/solrsearch/select?q=g:<groupId>+AND+a:<artifactId>&core=gav&rows=100&wt=json` |
| Gradle wrapper | `https://services.gradle.org/versions/all` |
| npm | `https://registry.npmjs.org/<package>` (`.versions` keys) |
| PyPI | `https://pypi.org/pypi/<package>/json` (`.releases` keys) |
| NuGet | `https://api.nuget.org/v3-flatcontainer/<package_lower>/index.json` |
| RubyGems | `https://rubygems.org/api/v1/versions/<gem>.json` |
| Go proxy | `https://proxy.golang.org/<module>/@v/list` |
| Cargo | `https://crates.io/api/v1/crates/<crate>/versions` |
| GitHub Actions | `https://api.github.com/repos/<owner>/<repo>/releases` |
