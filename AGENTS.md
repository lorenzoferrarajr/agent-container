# agent-in-container

Docker image bundling multiple AI coding agent CLIs in one sandboxed environment, so any of them can be run against a project dir without touching host system directly.

## Agents bundled

- Claude Code
- Codex CLI
- Gemini CLI
- opencode
- pi

## Design

- Container entrypoint: bash prompt (no agent auto-starts). User picks and launches whichever agent CLI they want from the shell.
- Working dir: the host dir the container was started from is mounted into container with **read-write** access — agents operate here.
- Config dirs mounted **read-write** — each agent can manage its own creds/settings/session state from inside the container, and it persists back to the host (e.g. `/login` inside the container works and sticks):
  - `~/.claude`, `~/.claude.json`
  - `~/.agents`
  - `~/.opencode`, `~/.config/opencode`
  - `~/.codex`
  - `~/.pi`

## Structure

Two-layer image, split so agent CLIs (updated daily) rebuild fast without reinstalling all the slow-changing system/python deps:

- `Dockerfile.base` — node base image + all system/python deps (git, python3, calibre, poppler, docling, etc). Tag: `agent-in-container-base:latest`. Rebuild only when deps change.
- `Dockerfile` — `FROM agent-in-container-base:latest`, installs just the agent CLIs via npm. Tag: `agent-in-container:latest`. Rebuild daily to pick up agent updates.
- `build-base.sh` — builds/tags the base image.
- `build-agents.sh` — `--no-cache` rebuild of agents image only, so npm installs always fetch latest.
- `agent-container` — standalone `docker run` wrapper script (no compose). Symlink onto `$PATH` and invoke from any project dir.

## Usage

First time (and whenever base deps change): `./build-base.sh`, then `./build-agents.sh`.

Put `agent-container` on `$PATH`, e.g.:

```
ln -s /path/to/agent-in-container/agent-container /usr/local/bin/agent-container
```

Then from any project root:

```
agent-container            # plain bash prompt in container
agent-container claude     # claude --dangerously-skip-permissions
agent-container codex      # codex --dangerously-bypass-approvals-and-sandbox
agent-container opencode   # opencode --auto
agent-container pi         # pi (no gate found to bypass, runs as-is)
```

Extra args after the agent name are forwarded to the CLI, e.g. `agent-container claude "fix the bug"`.

Mounts `$PWD` -> `/workspace` (rw). All config dirs/files mount rw too, skipped if absent on host: `~/.claude ~/.agents ~/.opencode ~/.codex ~/.pi` -> `/home/agent/<name>`, `~/.claude.json` -> `/home/agent/.claude.json`, `~/.config/opencode` -> `/home/agent/.config/opencode`.

Container runs as the host user's uid:gid (`--user "$(id -u):$(id -g)"`), not root — claude refuses `--dangerously-skip-permissions` as root. `$HOME` is forced to `/home/agent` (world-writable dir baked into the base image, `chmod 1777`) since the numeric uid has no `/etc/passwd` entry inside the container.

## YOLO mode

Each supported agent name maps to its CLI invoked with full-autonomy flag baked in (see table above) — no per-step approval prompts. This is the whole point of running them in the container: sandboxed blast radius (workdir rw, everything else ro) makes YOLO mode acceptable.

To pick up latest agent CLI versions: `./build-agents.sh` (daily, e.g. via cron), reuses cached base layer.

## Bundled tooling

- bash, git, curl, wget, build-essential
- python3 + pip (docling, ebooklib, beautifulsoup4, python-docx, striprtf)
- coreutils, findutils, grep, sed, gawk, less, vim, jq, zip/unzip, procps
- poppler-utils (pdf), calibre (`ebook-convert`)
- docker CLI (no daemon) — talks to host docker via `/var/run/docker.sock` mount (docker-outside-of-docker, not true DinD). `agent-container` mounts the socket and `--group-add`s its gid only if `/var/run/docker.sock` exists on host. Note: this gives container processes root-equivalent control of the host's docker daemon — a real hole in the "safe space" isolation, accepted tradeoff for this approach.

## Agent install refs

- claude code: `npm i -g @anthropic-ai/claude-code`
- codex cli: `npm i -g @openai/codex`
- gemini cli: `npm i -g @google/gemini-cli`
- opencode: `npm i -g opencode-ai`
- pi: `npm i -g --ignore-scripts @earendil-works/pi-coding-agent` (https://pi.dev)

## Notes

- "Safe space" = agents run isolated in container, can't write outside mounted workdir + config dirs.
- Config dirs are rw (see above) so agents can manage their own auth/settings — not a sandbox against the agent itself, just isolation from the rest of the host filesystem.
- No agent should be given host system access beyond these mounts.
