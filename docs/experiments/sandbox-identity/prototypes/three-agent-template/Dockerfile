FROM docker.io/docker/sandbox-templates@sha256:7fa049b8d7a0cf10f6a4200148ee475e94fc4fb5ef50dfacc4257699cb9a34bc AS claude
FROM docker.io/docker/sandbox-templates@sha256:d52a813951597a7ac700371ef5a8e7351eb7fe79d1788455d9b34813c3a6502e AS codex
FROM docker.io/docker/sandbox-templates@sha256:e21edce87d378167fdd3c021a21e0856eaa37b9ed9b058dbd57140f26ced1430 AS copilot

FROM docker.io/docker/sandbox-templates@sha256:c183a8ba03cdb30011c73f555c773c5712b84c6ea066f18409253dcab2cfe799

LABEL org.opencontainers.image.title="Muximate disposable three-agent sandbox prototype"
LABEL org.opencontainers.image.description="Experimental credential-free Claude, Codex, and Copilot composition"
LABEL org.opencontainers.image.source="https://github.com/aydabd/muximate"
LABEL org.muximate.experimental="true"
LABEL org.muximate.claude.version="2.1.221"
LABEL org.muximate.codex.version="0.146.0"
LABEL org.muximate.copilot.version="1.0.78"

COPY --from=claude --chown=1000:1000 /home/agent/.local/share/claude /home/agent/.local/share/claude
COPY --from=claude --chown=1000:1000 /home/agent/.local/bin/claude /home/agent/.local/bin/claude
COPY --from=codex --chown=1000:1000 /usr/local/share/npm-global/lib/node_modules/@openai/codex /usr/local/share/npm-global/lib/node_modules/@openai/codex
COPY --from=copilot --chown=1000:1000 /home/agent/.local/bin/copilot /home/agent/.local/bin/copilot
RUN mkdir -p /usr/local/share/npm-global/bin \
    && ln -s ../lib/node_modules/@openai/codex/bin/codex.js /usr/local/share/npm-global/bin/codex

USER agent
CMD ["/bin/bash"]
