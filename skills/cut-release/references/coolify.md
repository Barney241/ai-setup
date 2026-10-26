# Coolify quirks

Learned on self-hosted Coolify v4 behind Traefik. App UUIDs, hosts and env
belong in the repo's `.agents/loadout.md`, not here.

## Deploying

- Use the Coolify MCP `deploy` per app with `wait: true`, or
  `redeploy_project` for a whole project. Over REST, `/api/v1/deploy?uuid=…`
  is a POST.
- Pushing does not deploy when Coolify is only reachable on a private network
  (a tailnet): the GitHub webhook cannot reach it. Deploy explicitly.
- Each app builds its branch HEAD. Deploy only when the release commit is
  HEAD.
- After a deploy, `get_application` should report `running:healthy`. A
  service without a health check reports `running:unknown`. If an app is
  `restarting`, read its logs before anything else.
- Build arguments are baked in at build time. Set them before the deploy.
- Env values may be hidden from the API token. `env_vars list` still shows
  whether a key exists.

## Apps created over the API

Apps created through the MCP or API come up without the auto-generated
Traefik labels, so the domain serves Traefik's default certificate and 404s.
Set `custom_labels` (base64) explicitly, then restart the app. For host `H`,
app uuid `U`, container port `P`:

```
traefik.enable=true
traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https
traefik.http.routers.http-0-<U>.entryPoints=http
traefik.http.routers.http-0-<U>.middlewares=redirect-to-https
traefik.http.routers.http-0-<U>.rule=Host(`<H>`) && PathPrefix(`/`)
traefik.http.routers.http-0-<U>.service=http-0-<U>
traefik.http.routers.https-0-<U>.entryPoints=https
traefik.http.routers.https-0-<U>.rule=Host(`<H>`) && PathPrefix(`/`)
traefik.http.routers.https-0-<U>.service=https-0-<U>
traefik.http.routers.https-0-<U>.tls=true
traefik.http.routers.https-0-<U>.tls.certresolver=letsencrypt
traefik.http.services.http-0-<U>.loadbalancer.server.port=<P>
traefik.http.services.https-0-<U>.loadbalancer.server.port=<P>
```

For a first registration whose fields the MCP does not cover cleanly, create
the app in the UI and mirror the target config there.

## Networking

- Apps get no network alias by default. An app is reachable by name only with
  both `custom_docker_run_options: --network-alias <name>` and
  `custom_network_aliases: <name>`. The API rejects `custom_network_aliases`,
  so set it in the UI, then redeploy. A restart does not apply it.
- The Dockerfile build pack ignores a per-app start command. To run one image
  in two roles, switch on an env var in the image's entrypoint.

## MCP server

The Coolify MCP (`@masonator/coolify-mcp`) needs `COOLIFY_BASE_URL` and
`COOLIFY_ACCESS_TOKEN`. Keep the token in the repo's ignored `.env` and start
the server through a wrapper that reads it, never inline in `.mcp.json`.
