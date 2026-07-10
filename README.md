# agent-container

Docker image bundling multiple AI coding agent CLIs in one sandboxed environment, so you can run any of them against a project directory without giving them direct access to your host system.

Agents run in **YOLO mode** (full autonomy, no per-step approval prompts) — safe to do because the container's blast radius is limited: only the project working directory and each agent's own config dir are writable, everything else is isolated.

## Agents bundled

- Claude Code
- Codex CLI
- Gemini CLI
- opencode
- pi

## Usage

First time setup (and whenever base deps change):

```
./build-base.sh
./build-agents.sh
```

Put `agent-container` on your `$PATH`:

```
ln -s /path/to/agent-container/agent-container /usr/local/bin/agent-container
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

## Design

- **Container entrypoint**: bash prompt, no agent auto-starts. Pick and launch whichever agent CLI you want from the shell.
- **Working dir**: the host dir the container was started from mounts into the container with **read-write** access — agents operate here.
- **Config dirs** mount **read-write** too — each agent manages its own creds/settings/session state from inside the container, and it persists back to the host (e.g. `/login` inside the container works and sticks):
  - `~/.claude`, `~/.claude.json`
  - `~/.agents`
  - `~/.opencode`, `~/.config/opencode`, `~/.local/share/opencode` (model auth), `~/.local/state/opencode` (TUI state, e.g. last-used model)
  - `~/.codex`
  - `~/.pi`
- `~/.gitconfig` mounts **read-only** if present — gives commits a real author identity without granting push/GitHub credentials.
- Container runs as the host user's uid:gid (not root — Claude refuses `--dangerously-skip-permissions` as root). `$HOME` is forced to `/home/agent` (world-writable, baked into the base image).

## Structure

Two-layer image, split so agent CLIs (updated daily) rebuild fast without reinstalling all the slow-changing system/python deps:

- `Dockerfile.base` — node base image + all system/python deps (git, python3, calibre, poppler, docling, etc). Tag: `agent-container-base:latest`. Rebuild only when deps change.
- `Dockerfile` — `FROM agent-container-base:latest`, installs just the agent CLIs via npm. Tag: `agent-container:latest`. Rebuild daily to pick up agent updates.
- `build-base.sh` — builds/tags the base image.
- `build-agents.sh` — `--no-cache` rebuild of agents image only, so npm installs always fetch latest.
- `agent-container` — standalone `docker run` wrapper script (no compose). Symlink onto `$PATH` and invoke from any project dir.

To pick up latest agent CLI versions: `./build-agents.sh` (daily, e.g. via cron), reuses cached base layer.

## Bundled tooling

- bash, git, curl, wget, build-essential
- python3 + pip (docling, ebooklib, beautifulsoup4, python-docx, striprtf)
- coreutils, findutils, grep, sed, gawk, less, vim, jq, zip/unzip, procps
- poppler-utils (pdf), calibre (`ebook-convert`)
- docker CLI (no daemon) — talks to host docker via `/var/run/docker.sock` mount (docker-outside-of-docker, not true DinD). `agent-container` mounts the socket and `--group-add`s its gid only if `/var/run/docker.sock` exists on host.

  **Note**: this gives container processes root-equivalent control of the host's docker daemon — a real hole in the "safe space" isolation, accepted tradeoff for convenience. Don't use this if that's not acceptable for your threat model.

## Agent install refs

- claude code: `npm i -g @anthropic-ai/claude-code`
- codex cli: `npm i -g @openai/codex`
- gemini cli: `npm i -g @google/gemini-cli`
- opencode: `npm i -g opencode-ai`
- pi: `npm i -g --ignore-scripts @earendil-works/pi-coding-agent` (https://pi.dev)

## Caveats

- "Safe space" = agents run isolated in the container, can't write outside mounted workdir + config dirs. Config dirs are rw so agents can manage their own auth/settings — this isn't a sandbox against the agent itself, just isolation from the rest of the host filesystem.
- No agent should be given host system access beyond these mounts.
- Docker socket mount (if present) is a known exception to the above — see Bundled tooling.

## License

MIT — see [LICENSE](LICENSE).
