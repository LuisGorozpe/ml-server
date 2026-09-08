HOWTO: Multi-arch builds and docker buildx

This document explains practical steps to build multi-architecture images for this project and how to use them so ARM devices (e.g. RK3588) and x86_64 hosts can both run the stack.

Prerequisites

- Docker 20.10+ with buildx available (usually included). Verify with: docker buildx version
- QEMU user static installed on the host if you plan to emulate other architectures locally (many distros have packages like qemu-user-static). To enable emulation for buildx, run: docker run --privileged --rm tonistiigi/binfmt --install all

Create and use a buildx builder

1. Create a builder instance and use it:

   docker buildx create --name multi-builder --use
   docker buildx inspect --bootstrap

2. To build and push multi-arch images for a specific service (example: jupyterlab):

   docker buildx build --platform linux/amd64,linux/arm64 -t <registry>/jupyterlab:latest --push ./jupyterlab

   Replace <registry> with your registry (docker.io/youruser, ghcr.io/yourorg, or a private registry).

Using build args to switch base image

The recommended Dockerfile pattern uses build args: `ARG BASE_IMAGE` and `ARG ARCH`. Use docker-compose build with build-args or pass them directly to buildx:

   docker buildx build --platform linux/amd64 -t my/jupyterlab:amd64 --build-arg BASE_IMAGE=debian:bookworm-slim --build-arg ARCH=amd64 --push ./jupyterlab

Local development with docker-compose

- You can still use `docker compose up --build` locally. To force a specific platform in docker-compose, set `platform: linux/amd64` under the service, or provide build args in the compose file.

Example snippet for docker-compose.yml service build section:

  jupyterlab:
    build:
      context: ./jupyterlab
      args:
        BASE_IMAGE: debian:bookworm-slim
        ARCH: amd64
    platform: linux/amd64

Notes and troubleshooting

- Building natively on the target (ARM device) produces images that will run without emulation, but builds can be slow. Use buildx on a powerful machine to produce images and push to a registry.
- If you get errors installing architecture-specific wheels (tensorflow-aarch64, etc.), consider conditional installs in the Dockerfile based on $ARCH.
- For reproducibility, pin image tags rather than using :latest.

Security and distribution

- Store your built images in a private registry if they contain sensitive configuration.
- For production, avoid building images on the device; instead perform CI builds and push signed images to a trusted registry.

Common commands summary

- Create builder: docker buildx create --name multi-builder --use
- Build multi-arch and push: docker buildx build --platform linux/amd64,linux/arm64 -t <registry>/jupyterlab:latest --push ./jupyterlab
- Build single-platform (amd64): docker buildx build --platform linux/amd64 -t <registry>/jupyterlab:amd64 --push ./jupyterlab
- Run compose with build args: docker compose build --build-arg BASE_IMAGE=debian:bookworm-slim --build-arg ARCH=amd64

