# LTS Version Sources

Use `web_fetch` or the REST APIs below to resolve the current LTS version for a technology.
Always prefer the official source. Fall back to `https://endoflife.date/api/<product>.json`.

---

## Java (JDK)

**API:**
```
GET https://api.adoptium.net/v3/info/available_releases
```
Field: `most_recent_lts` (integer, e.g. `21`)

Then resolve the latest release of that LTS:
```
GET https://api.adoptium.net/v3/assets/latest/<lts_version>/hotspot?os=linux&architecture=x64&image_type=jdk
```
Or simply use `<lts_version>` as the version to put in build files (e.g. `21`).

---

## Node.js

**API:**
```
GET https://nodejs.org/dist/index.json
```
Find the latest entry where `lts != false`. The `lts` field contains the LTS codename (e.g. `"Iron"`).
Use the `version` field (e.g. `v20.18.0`) — strip the `v` prefix for build files.

Alternatively:
```
GET https://endoflife.date/api/nodejs.json
```
Latest entry where `lts == true` and `eol` is in the future.

---

## Python

```
GET https://endoflife.date/api/python.json
```
Latest entry where `eol` is in the future. Python does not have an official "LTS" label — the
latest stable release series with future EOL is treated as LTS.

---

## .NET

```
GET https://endoflife.date/api/dotnet.json
```
Find the latest entry where `lts == true` and `eol` is in the future.

Official confirmation: `https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core`

---

## Ruby

```
GET https://endoflife.date/api/ruby.json
```
Latest entry where `eol` is in the future.

---

## Go

Go does not have a formal LTS. `latest` and `lts` are treated the same — use the current stable release.
```
GET https://go.dev/dl/?mode=json
```
First entry's `version` field (e.g. `go1.22.3`) — strip the `go` prefix for build files.

---

## Rust

Rust does not have LTS releases. `lts` is treated as `latest`.
```
GET https://static.rust-lang.org/dist/channel-rust-stable.toml
```
Or simply: `rustup update stable`

---

## Spring Boot

Spring Boot has commercial LTS ("OSS support ends" dates). Check:
```
https://spring.io/projects/spring-boot#support
```
Or use `web_fetch` on that URL and look for the "OSS support" timeline to identify the current generation.

---

## Ubuntu / Debian (Docker base images)

LTS Ubuntu releases: 20.04 (Focal), 22.04 (Jammy), 24.04 (Noble).
```
GET https://endoflife.date/api/ubuntu.json
```
Latest entry where `lts == true` and `eol` is in the future.

---

## Fallback for any technology

```
GET https://endoflife.date/api/<product>.json
```
Replace `<product>` with the lowercase product name (e.g. `java`, `nodejs`, `python`, `ruby`, `go`, `dotnet`, `php`, `mysql`, `postgresql`, `redis`).

Full product list: `https://endoflife.date/api/all.json`

If the API returns no result or the technology is not listed, ask the user for the target version.
