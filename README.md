# ML Server — Machine Learning Data Lab

This repository contains a Docker Compose setup and a set of Dockerfiles to deploy a Machine Learning "Data Lab": Jupyter/JupyterHub, MLflow, MinIO (artifacts), code-server (remote IDE) and other utilities.

Key files and folders

- [docker-compose.yml](/home/leag555/mlserver/ml-server/docker-compose.yml) — service and volume definitions.
- [jupyterlab/Dockerfile](/home/leag555/mlserver/ml-server/jupyterlab/Dockerfile) — Dockerfile used to build the JupyterLab/JupyterHub image (ARM-oriented by default).
- [code-server/](/home/leag555/mlserver/ml-server/code-server) — folder with code-server build (VS Code in the browser).
- [jupyterlab/](/home/leag555/mlserver/ml-server/jupyterlab) — build context for the jupyterlab service.

Architecture summary

The stack provided by this project includes:

- jupyterlab (JupyterHub inside a container) — interactive environment with Python, R, Julia and Rust kernels.
- mlflow — experiment tracking server.
- minio — S3-compatible storage used as MLflow artifact backend.
- code-server — VS Code in the browser for remote editing.
- marimo — an auxiliary service (local context).

Services are orchestrated with Docker Compose and persist data in Docker volumes (configured in docker-compose.yml).

Designed and tested on Orange Pi 5 Plus (ARM)

This project was designed, tested and deployed on an Orange Pi 5 Plus (ARM). The default image for the JupyterLab service is based on an Armbian image ([jupyterlab/Dockerfile](/home/leag555/mlserver/ml-server/jupyterlab/Dockerfile)), therefore packages and installations (for example, tensorflow-aarch64) are tailored for ARM platforms. It can also run on other ARM servers (for example running DiePi/Armbian) or be adapted to other ARM devices.

Important notes for ARM

- The Dockerfile uses: `FROM ophub/armbian-bookworm` — a base that is ARM-friendly; keep it for RK/ARM devices like Orange Pi 5 Plus.
- Packages like `tensorflow-aarch64` and other ARM-specific wheels are referenced in the Dockerfile.
- The repository installs kernels for R, Julia and Rust; those steps may trigger compilation or package downloads that can take significant time on small ARM boards.
- Consider enabling swap or using a more powerful host to build images (especially when compiling Rust/Julia packages or installing heavy Python dependencies).

Adapting to x86_64 (Intel/AMD)

Although the default configuration targets ARM, the project can be adapted to a traditional x86_64 architecture. Recommendations to adapt Dockerfiles and Docker Compose:

1) Parameterize the Dockerfile base image

Modify the Dockerfile header to accept a build argument for the base image, for example:

```
# Suggested pattern for jupyterlab/Dockerfile
ARG BASE_IMAGE=ophub/armbian-bookworm
FROM ${BASE_IMAGE}
```

This allows building with:

- On ARM (default): `docker compose build` (or `docker compose up --build`) without changes.
- On x86: `docker compose build --build-arg BASE_IMAGE=debian:bookworm-slim`

2) Use Docker Buildx for multi-architecture images

To create multi-arch images (arm64 and amd64) and/or test locally on x86, use docker buildx:

- Initialize buildx if needed: `docker buildx create --use`
- Build multi-arch image (example):
  `docker buildx build --platform linux/amd64,linux/arm64 -t my-registry/jupyterlab:latest --push ./jupyterlab`

3) Handle architecture-specific dependencies

- The Dockerfile currently installs architecture-specific packages such as `tensorflow-aarch64`. For x86, replace with `tensorflow` or use conditional installs based on build arguments (`ARCH`).
- PyTorch: the Dockerfile uses `--index-url https://download.pytorch.org/whl/cpu` for CPU wheels; for GPU or other platforms select the appropriate wheels or indices.

Recommended pattern inside Dockerfile to branch on architecture:

```
ARG ARCH=arm64
ENV ARCH=${ARCH}
# Then during RUN steps choose based on $ARCH
# Example pseudo step:
# RUN if [ "$ARCH" = "arm64" ]; then pip install tensorflow-aarch64; else pip install tensorflow; fi
```

4) Declare platform in docker-compose.yml (optional)

On x86 hosts you can force the platform per-service (useful when images are multi-arch or require emulation):

```
services:
  jupyterlab:
    build:
      context: ./jupyterlab
      args:
        - BASE_IMAGE=debian:bookworm-slim
        - ARCH=amd64
    platform: linux/amd64
```

Important image/source adjustments

- [jupyterlab/Dockerfile](/home/leag555/mlserver/ml-server/jupyterlab/Dockerfile) — change the header to `ARG BASE_IMAGE` and conditionally install artefacts (tensorflow, torch, etc.) based on ARCH or BASE_IMAGE.
- mlflow service uses `image: ghcr.io/mlflow/mlflow` — verify its multi-arch compatibility; if not multi-arch, consider building a local image or using `platform:` in docker-compose to force emulation.
- MinIO: the image `pgsty/silo:latest` is a wrapper; evaluate using the official `minio/minio` image and pin versions/architectures if you need official multi-arch support.

Quick start (on ARM Orange Pi 5 Plus)

On an ARM host (Orange Pi 5 Plus with Docker installed):

1. Build and bring up the stack:
   `docker compose up --build -d`

2. Access services:
   - JupyterHub/JupyterLab: http://<host>:8888
   - MLflow: http://<host>:5000
   - MinIO Console: http://<host>:9001 (default credentials in docker-compose.yml: minio / miniopass)
   - code-server: http://<host>:8080

Configuration and security notes

- Change default credentials: MINIO_ROOT_USER, MINIO_ROOT_PASSWORD, and any internal credentials before exposing to untrusted networks.
- Mount volumes to host directories for persistence and backups. For example: `./data/minio:/data` instead of anonymous volumes.
- For Internet-exposed deployments, protect services behind a reverse proxy (nginx, Traefik) with TLS termination. Avoid exposing admin ports directly.

Performance recommendations for Orange Pi 5 Plus

- Enable swap cautiously if builds fail due to OOM when installing large dependencies.
- Prefer precompiled wheels for ARM (e.g., `tensorflow-aarch64`) or community-optimized builds for RK devices.
- If local builds are slow, build images on a more powerful x86 host using buildx and push to a registry for the ARM device to pull.

Additional considerations and best practices

- Pin image tags for reproducibility instead of using `:latest`.
- Separate development and production concerns: do not store secrets in plaintext files in production; use Docker secrets, environment variables from a secure store, or Vault.
- Add service healthchecks in docker-compose to validate that endpoints are ready.

Suggested minimal Dockerfile header (jupyterlab/Dockerfile)

```
# Default: ARM support; override with --build-arg BASE_IMAGE=debian:bookworm-slim for x86
ARG BASE_IMAGE=ophub/armbian-bookworm
ARG ARCH=arm64
FROM ${BASE_IMAGE}
ENV ARCH=${ARCH}
```

docker-compose build snippet example to pass args and platform:

```
  jupyterlab:
    build:
      context: ./jupyterlab
      args:
        BASE_IMAGE: debian:bookworm-slim
        ARCH: amd64
    platform: linux/amd64
```

.env file and .env.example

To make deployments flexible and avoid editing source files directly, use a `.env` file in the project root. A `.env.example` is included. Copy `.env.example` to `.env` and edit values before running `docker compose`.

The example file includes variables for base image selection, architecture, ports, and credentials. Never commit `.env` with real secrets to version control.

Security warning

This project as provided is intended as a Machine Learning Data Lab for individual use or development. It is NOT secure for production use out of the box: credentials are presented as examples, ports are exposed and there is no TLS/proxy by default. Do not deploy publicly without appropriate hardening (reverse proxy with TLS, secrets management, firewall rules, image hardening).

HOWTO: multi-arch and docker buildx

See [HOWTO-multiarch.md](/home/leag555/mlserver/ml-server/HOWTO-multiarch.md) for practical steps to build multi-architecture images and best practices.

Contact

This README was generated to document the project and guide adaptation between ARM and x86. If automatic changes to Dockerfiles (ARG parametrization) are desired, those can be applied upon request.

---

# ML Server — Data Lab para Machine Learning

Este repositorio contiene una composición Docker (Docker Compose) y un conjunto de Dockerfiles para desplegar un "Data Lab" orientado a tareas de Machine Learning: Jupyter/JupyterHub, MLflow, MinIO (artefactos), code-server (IDE remota) y otras utilidades.

Principales archivos y carpetas

- [docker-compose.yml](/home/leag555/mlserver/ml-server/docker-compose.yml) — definición de servicios y volúmenes.
- [jupyterlab/Dockerfile](/home/leag555/mlserver/ml-server/jupyterlab/Dockerfile) — Dockerfile usado para la imagen de JupyterLab/JupyterHub (orientado a ARM).
- [code-server/](/home/leag555/mlserver/ml-server/code-server) — carpeta con build de code-server (IDE en navegador).
- [jupyterlab/](/home/leag555/mlserver/ml-server/jupyterlab) — contexto de construcción del servicio jupyterlab.

Resumen arquitectural

El stack que provee este proyecto incluye:

- jupyterlab (JupyterHub en contenedor) — entorno interactivo con kernels de Python, R, Julia y Rust.
- mlflow — servidor de tracking de experimentos.
- minio — almacenamiento S3-compatible usado como backend de artefactos de MLflow.
- code-server — VS Code en el navegador para edición remota.
- marimo — servicio adicional (contexto local). 

Los servicios se orquestan con Docker Compose y persisten datos en volúmenes Docker (definidos en docker-compose.yml).

Diseñado para ARM (Orange Pi RK3588)

Este proyecto fue diseñado, probado y desplegado en un Orange Pi 5 Plus (ARM). La imagen por defecto para el servicio JupyterLab está basada en una imagen Armbian ([jupyterlab/Dockerfile](/home/leag555/mlserver/ml-server/jupyterlab/Dockerfile)), por lo que los paquetes compilados e instalaciones (por ejemplo, tensorflow-aarch64) están orientados a ARM. También puede ejecutarse en otros servidores ARM (por ejemplo con DiePi/Armbian) y puede adaptarse a otros dispositivos ARM.

Puntos importantes para ARM:

- El Dockerfile usa: `FROM ophub/armbian-bookworm` — esto apunta a una base arm-friendly; mantenerlo en dispositivos RK3588/ARM es recomendable.
- Paquetes como `tensorflow-aarch64` y ruedas específicas para CPU ARM están ya referenciados en el Dockerfile.
- El repositorio instala kernels para R, Julia y Rust; esto implica compilación/instalación en tiempo de build, que en algunas placas ARM puede tardar bastante.
- Recomendar habilitar suficiente swap o usar un host con recursos adecuados al construir las imágenes (especialmente al compilar paquetes Rust/Julia o instalar grandes dependencias Python).

Adaptación a arquitecturas x86_64 (Intel/AMD)

Aunque la configuración por defecto apunta a ARM, el proyecto se puede adaptar a una arquitectura tradicional x86_64. Recomendaciones para adaptar las imágenes y Docker Compose:

1) Dockerfile base parametrizable

Modificar la cabecera del Dockerfile para aceptar un argumento de base, por ejemplo:

```
# Ejemplo sugerido para jupyterlab/Dockerfile
ARG BASE_IMAGE=ophub/armbian-bookworm
FROM ${BASE_IMAGE}
```

Así se puede construir con:

- En ARM (por defecto): docker compose build (o docker compose up --build) sin cambios.
- En x86: docker compose build --build-arg BASE_IMAGE=debian:bookworm-slim

2) Usar Docker Buildx para imágenes multi-arquitectura

Para crear imágenes multi-arch (arm64 y amd64) y/o probar localmente en x86, usar docker buildx:

- Inicializar buildx si no existe: docker buildx create --use
- Construir multiarch (ejemplo):
  docker buildx build --platform linux/amd64,linux/arm64 -t mi-registro/jupyterlab:latest --push ./jupyterlab

3) Ajustes de dependencias específicas de arquitectura

- En el Dockerfile se instalan paquetes específicos como `tensorflow-aarch64`. Para x86, reemplazar por `tensorflow` o usar condicionales basados en build-arg ARCH.
- PyTorch: en el Dockerfile actual se usa `--index-url https://download.pytorch.org/whl/cpu` para la rueda CPU; para GPU o plataformas distintas se debe elegir el índice/tags adecuados.

Sugerencia de patrón para manejar dependencias por arquitectura dentro del Dockerfile:

```
ARG ARCH=arm64
ENV ARCH=${ARCH}
# luego en pasos RUN, elegir según $ARCH
# ejemplo (pseudo):
# RUN if [ "$ARCH" = "arm64" ]; then pip install tensorflow-aarch64; else pip install tensorflow; fi
```

4) Declarar plataforma en docker-compose.yml (opcional)

En equipos x86 se puede forzar la plataforma en cada servicio (útil cuando se usan imágenes multi-arch o emulación):

```
services:
  jupyterlab:
    build:
      context: ./jupyterlab
      args:
        - BASE_IMAGE=debian:bookworm-slim
        - ARCH=amd64
    platform: linux/amd64
```

Modificaciones importantes en fuentes de imágenes

- [jupyterlab/Dockerfile](/home/leag555/mlserver/ml-server/jupyterlab/Dockerfile) — cambiar la cabecera a `ARG BASE_IMAGE` y condicionar la instalación de artefactos (tensorflow, torch, etc.) según ARCH o BASE_IMAGE.
- Servicio mlflow: actualmente usa `image: ghcr.io/mlflow/mlflow` — comprobar compatibilidad multi-arch; si no es multi-arch, construir una imagen local o usar `platform:` en docker-compose para forzar emulación.
- MinIO: la imagen `pgsty/silo:latest` es un wrapper; evaluar usar `minio/minio` oficial y fijar versión/arquitectura si se buscan binarios multi-arch.

Cómo ejecutar (rápido)

En una máquina ARM (Orange Pi RK3588 con Docker instalado):

1. Construir y levantar:
   docker compose up --build -d

2. Acceder:
   - JupyterHub/JupyterLab: http://<host>:8888
   - MLflow: http://<host>:5000
   - MinIO Console: http://<host>:9001 (credenciales por defecto en docker-compose.yml: minio / miniopass)
   - code-server: http://<host>:8080

Notas de configuración y seguridad

- Cambiar contraseñas por defecto: MINIO_ROOT_USER, MINIO_ROOT_PASSWORD, y las credenciales internas (si se exponen en producción).
- Vincular volúmenes a rutas persistentes del host para backup y rendimiento. Ejemplo en docker-compose: `./data/minio:/data` en vez de depender únicamente de volúmenes anónimos.
- Para entornos accesibles desde Internet, proteger con un proxy inverso (nginx, Traefik) y habilitar TLS. Evitar exponer puertos administrativos sin autenticación.

Recomendaciones para rendimiento en RK3588

- Habilitar swap (con cuidado) si la compilación local falla por OOM durante instalación de dependencias grandes.
- Preferir ruedas precompiladas para ARM (p. ej. `tensorflow-aarch64`) o usar versiones optimizadas por la comunidad para RK3588.
- Si la compilación local resulta muy lenta, construir la imagen en un host más potente (x86) usando buildx y push a un registro privado/mixto para luego tirar la imagen en ARM.

Consideraciones adicionales y buenas prácticas

- Pin de versiones: fijar tags de imágenes oficiales (mlflow, minio) para reproducibilidad.
- Separar entorno de desarrollo y producción: eliminar credenciales en texto plano y usar variables de entorno o secretos (Docker secrets, Vault).
- Tests de arranque: añadir un pequeño script healthcheck para cada servicio en docker-compose para comprobar que los endpoints estén disponibles.

Ejemplos de cambios mínimos recomendados

1) Cabecera sugerida para [jupyterlab/Dockerfile](/home/leag555/mlserver/ml-server/jupyterlab/Dockerfile):

```
# Soporte por defecto para ARM; cambiar con --build-arg BASE_IMAGE=debian:bookworm-slim para x86
ARG BASE_IMAGE=ophub/armbian-bookworm
ARG ARCH=arm64
FROM ${BASE_IMAGE}
ENV ARCH=${ARCH}
```

2) Ejemplo para docker-compose.yml (snippet) para forzar build arg y plataforma:

```
  jupyterlab:
    build:
      context: ./jupyterlab
      args:
        BASE_IMAGE: debian:bookworm-slim
        ARCH: amd64
    platform: linux/amd64
```

Siguientes pasos sugeridos

- Si se desea, aplicar la parametrización del Dockerfile (ARG BASE_IMAGE, ARG ARCH) y actualizar docker-compose.yml para documentar opciones de build para ARM vs x86.
- Crear un pequeño HOWTO de creación de imágenes multi-arch con docker buildx y publicar imágenes en un registro si se quiere acelerar despliegues en múltiples tipos de hardware.

Archivo .env y .env.example

Para facilitar despliegues parametrizados y evitar editar archivos fuente directamente, es recomendable usar un archivo .env en la raíz del proyecto. A continuación se incluye un archivo de ejemplo (.env.example) con variables recomendadas que permiten adaptar la construcción y la ejecución entre arquitecturas (ARM vs x86) y centralizar credenciales/configuración.

- Colocar un archivo `.env` en la raíz con valores específicos del entorno antes de ejecutar `docker compose up`.
- Nunca comitear el archivo `.env` con credenciales reales.

Variables sugeridas (ver .env.example)

- BASE_IMAGE — Imagen base para construir jupyterlab (ej. ophub/armbian-bookworm o debian:bookworm-slim).
- ARCH — Arquitectura objetivo (arm64 o amd64).
- JUPYTER_PORT, MLFLOW_PORT, MINIO_PORT, CODE_SERVER_PORT — Puertos expuestos en el host.
- MINIO_ROOT_USER, MINIO_ROOT_PASSWORD — Credenciales para MinIO (ej. cambiar por valores seguros).
- MLFLOW_BACKEND_STORE_URI — URI para el backend store de MLflow (por defecto sqlite:///mlflow.db).
- MLFLOW_ARTIFACT_ROOT — Ruta S3 para artefactos de MLflow (por defecto s3://mlflow/).

Advertencia de seguridad

Este proyecto, tal y como está, está pensado para un Data Lab de Machine Learning para uso individual o laboratorio. No es una configuración segura para producción: contiene credenciales en texto plano en los archivos de ejemplo y expone puertos sin un proxy/TLS por defecto. No usar en entornos públicos sin aplicar medidas adicionales (proxy inverso, TLS, gestión de secretos, firewalls, hardening de imágenes y usuarios).

HOWTO: multi-arch y buildx (ver HOWTO-multiarch.md)

Se añadió el archivo [HOWTO-multiarch.md](/home/leag555/mlserver/ml-server/HOWTO-multiarch.md) con pasos prácticos para:

- Crear y usar `docker buildx` para generar imágenes multi-arch.
- Construir y publicar imágenes para arm64 y amd64.
- Ejemplos de comandos para construir localmente, forzar plataforma en `docker-compose` y solucionar problemas comunes.

Contacto

Este README fue generado para documentar el proyecto y guiar la adaptación entre ARM y x86. Para cambios automáticos en los Dockerfiles (parametrización con ARG) puedo aplicarlos si se desea que haga las modificaciones en el repositorio.

