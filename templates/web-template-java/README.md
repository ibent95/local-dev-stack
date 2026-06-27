# web-template-java

Java **web app** using the native **Servlet API** (Jakarta Servlet, no
framework), server-rendered HTML, built to a WAR and run on Tomcat. Routed at
`http://web-template-java.test`.

> API counterpart: `svc-template-java`. Framework version: `web-template-springboot`.

## Run

```bash
../../scripts/run/up.sh proxy            # once
docker compose up -d                     # http://web-template-java.test (first build is slow)
```

Servlets don't hot-reload from a source mount — after editing
`src/main/java/com/example/HomeServlet.java`, rebuild:

```bash
docker compose up -d --build
```

## Production image

```bash
docker build --target prod -t web-java:prod .
```
