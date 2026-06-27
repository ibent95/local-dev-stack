# 06 · Hosting PHP projects (`www/`)

The `php` profile auto-hosts every folder under `www/` (Devilbox-style):

```
www/myshop/public/index.php → http://myshop.test
```

- Docroot is auto-detected per project: `public/` → `htdocs/` → folder root.
- No config or rebuild when adding a project — drop the folder and refresh.
- For `*.test` to resolve, set your adapter DNS to `127.0.0.1` (or use
  `lds hosts-sync`) — see [14 · DNS](14-dns.md).
- Serve your existing projects directly: set `PHP_PROJECTS_PATH` in `.env` to
  that parent folder (e.g. `PHP_PROJECTS_PATH=D:/projects/PHP`). It defaults to
  `./www`, the example folder shipped with LDS.

This is the **shared mass-vhost** mode (plain PHP, file-based). For
containerized projects in any language, use a template instead — see
[07](07-create-new-project.md).
