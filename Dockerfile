ARG BASE_IMAGE=agent-container-base:latest
FROM ${BASE_IMAGE}

# HOME is /home/agent (set in the base image) so it's writable at runtime by
# whatever host uid the container runs as (see agent-container's chmod 1777);
# but that means npm/opencode postinstall would write build-time cache and
# data dirs into /home/agent owned by root, blocking that runtime user. Build
# as root's own home instead, and let /home/agent stay empty for the runtime user.
RUN HOME=/root npm install -g \
        @anthropic-ai/claude-code \
        @openai/codex \
        @google/gemini-cli \
        opencode-ai \
    && HOME=/root npm install -g --ignore-scripts @earendil-works/pi-coding-agent

# claude's own health-check expects a self-managed copy at ~/.local/bin/claude;
# $HOME is ephemeral (fresh /home/agent per container run), so bake a symlink
# to the real npm-installed binary here to silence the "missing or broken" nag.
# mkdir -p leaves /home/agent/.local root-owned mode 755, which blocks the
# runtime (host-uid) user from creating siblings like .local/share (opencode
# does this) — chmod the whole tree open like the base image does for /home/agent.
RUN mkdir -p /home/agent/.local/bin \
    && ln -s "$(command -v claude)" /home/agent/.local/bin/claude \
    && chmod -R 1777 /home/agent/.local

WORKDIR /workspace

ENTRYPOINT ["/bin/bash"]
