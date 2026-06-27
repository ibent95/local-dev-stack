# web-template-springboot

Java + Spring Boot **web app** (server-rendered HTML via Thymeleaf) with
devtools hot-restart, routed at `http://web-template-springboot.test`. The API
counterpart is `svc-template-springboot` (returns JSON). Native (no-framework)
Java versions: `svc-template-java` / `web-template-java` (Servlet).

## Run

```bash
../../scripts/run/up.sh proxy     # once
docker compose up -d              # http://web-template-springboot.test (first build is slow)
```

View at `src/main/resources/templates/index.html`; controller in
`src/main/java/com/example/demo/HomeController.java`. The `maven-cache` volume
keeps `~/.m2` warm.

## Make your own

Copy into `D:\projects\Java\my-web`, set `APP_HOST`, adjust the package name,
`docker compose up -d`.

## Production image

```bash
docker build --target prod -t my-web:prod .
```
