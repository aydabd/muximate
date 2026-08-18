# Disposable three-agent template prototype

This experimental Linux/arm64 template composes the installed Claude, Codex, and Copilot artifacts
from four immutable official Docker Sandbox image digests. It performs no package installation,
downloads no installer script during the build, contains no credential, and is not published.

It is evidence for the minimal-hybrid architecture checkpoint, not a supported Muximate feature.
Docker Sandbox still records one agent type for a sandbox; composing the binaries does not prove
that three provider credential proxies, network policies, or interactive login flows can safely
coexist.

The local prototype build uses:

```sh
docker buildx build \
  --pull=false \
  --network none \
  --platform linux/arm64 \
  --load \
  --tag muximate-three-agent:phase6-arm64 \
  docs/experiments/sandbox-identity/prototypes/three-agent-template
```

Test the image without network access:

```sh
docker run --rm --network none \
  muximate-three-agent:phase6-arm64 \
  sh -c 'claude --version; codex --version; copilot --version'
```

Docker Sandbox uses a separate image store. Export and load the local image explicitly:

```sh
docker image save \
  muximate-three-agent:phase6-arm64 \
  --output /private/tmp/muximate-three-agent-phase6-arm64.tar
sbx template load /private/tmp/muximate-three-agent-phase6-arm64.tar
```

Never build this prototype with a credential in the build context, environment, Dockerfile, or
image layer. Never push it to a registry without a separate supply-chain and publication review.
The four pinned base images must already be present in the selected Docker daemon before the
network-disabled build. The experiment pulled those public images with an empty anonymous Docker
configuration and removed them after testing.
