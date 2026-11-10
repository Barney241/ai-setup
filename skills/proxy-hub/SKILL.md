---
name: proxy-hub
description: Use when the user asks about the proxy hub or CLI proxy: quota left, when an account resets, who used what, which account served a request, a 401, 429 or 503 through the proxy, adding a user or an account, or turning the hub on. Also use when they say "proxy hub" or "cliproxy".
---

# Proxy hub

CLIProxy Hub is my LLM proxy, a private fork of CLIProxyAPI. It runs on the
home server in front of the provider accounts signed in there. Every client
has its own access key, and a key reaches only the accounts assigned to its
user. `HUB.md` in the fork checkout (`~/Projects/personal/cliproxy-hub`) is
the reference for its API, storage, NixOS module and operating rules.

The hub is off until `programs.ai-setup.hub.url` is set on a host. If
`ai-setup hub` says it is not configured, say so. Do not look for another way
in.

## How to ask it

Use the `cliproxy-hub` MCP tools. In a shell, or if they are missing:

```bash
ai-setup hub                                  # lists the tools
ai-setup hub health
ai-setup hub accounts provider=claude
ai-setup hub usage hours=168
ai-setup hub recent-requests failed_only=true limit=20
ai-setup hub request request_id=<id>
```

Every tool is read-only and runs with the observer key. If the sandbox blocks
the connection, use the MCP tools or the sandbox bypass.

| Question | Use |
|---|---|
| Is it healthy, is it configured safely | `health`, read `warnings` first |
| Quota left, when does an account reset | `accounts` |
| Who has which accounts and keys | `users` |
| Who used how much, cache hit rate | `usage` |
| Why did a request fail | `recent-requests failed_only=true`, then `request` |

## Reading the answers

- `prompt_tokens` is everything sent, cached or not. Cache hit rate is
  `cache_read_tokens / prompt_tokens`.
- A window with `usage_known: false` has a reset time but no percentage.
- 401 from the hub: the key is unknown, disabled or revoked. 503 with no
  upstream attempt: the user has no usable account assigned, or every
  assigned account is out of quota. 429 or 403 from upstream: the provider
  itself refused, read the error excerpt and tell the user at once.
- Routing spends the account that resets soonest and keeps a conversation on
  the account it started on. One account taking all the traffic is the design,
  not a fault.

## What you may not do

- Never read, print or pass on the management key, a hub key secret or a file
  under the hub's `auths` directory. The observer key is the only credential an
  agent uses.
- Never sign an account in. Login is an OAuth flow the user finishes in a
  browser: `sudo cliproxy-hub -claude-login -no-browser` on the server.
- Changing users, keys or assignments happens in the dashboard at `/hub/`, by
  the user. Propose the change, do not make it.
- Never turn on upstream's client-impersonation or header-cloaking options.
- Before proposing any change to who uses which account, where the hub runs or
  how clients connect, read "Rules that keep accounts alive" in `HUB.md` and
  raise it when the user is about to break one.

## Turning it on

Nothing below is done until the user asks for it.

1. Create the agenix secret with `MANAGEMENT_PASSWORD` and
   `CLIPROXY_HUB_OBSERVER_KEY`, two different long random values.
2. In infinity-lab, turn the hub on for the home server, then deploy.
3. The user signs each account in on the server and opens the dashboard with
   the management key: add users, assign accounts, issue keys.
4. Put the observer key in `~/.config/ai-setup/hub-observer-key` (mode 600) on
   each host, set `programs.ai-setup.hub.url`, and run `ai-setup sync`. That
   registers the MCP server for Claude, Codex and Antigravity.
5. Run `ai-setup hub health`. It must report `soonest-reset`, session affinity
   on, and no warnings.
6. Point one client at the hub with its own hub key and watch
   `recent-requests` before moving anything else over.
