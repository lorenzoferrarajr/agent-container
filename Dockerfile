ARG BASE_IMAGE=agent-container-base:latest
FROM ${BASE_IMAGE}

RUN npm install -g \
        @anthropic-ai/claude-code \
        @openai/codex \
        @google/gemini-cli \
        opencode-ai \
    && npm install -g --ignore-scripts @earendil-works/pi-coding-agent

# claude's own health-check expects a self-managed copy at ~/.local/bin/claude;
# $HOME is ephemeral (fresh /home/agent per container run), so bake a symlink
# to the real npm-installed binary here to silence the "missing or broken" nag
RUN mkdir -p /home/agent/.local/bin \
    && ln -s "$(command -v claude)" /home/agent/.local/bin/claude

WORKDIR /workspace

ENTRYPOINT ["/bin/bash"]
