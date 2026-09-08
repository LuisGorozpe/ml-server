# ML Server — Machine Learning Data Lab

Table of Contents (English)

- [Key files and folders](#key-files-and-folders)
- [Architecture summary](#architecture-summary)
- [Designed and tested on Orange Pi 5 Plus (ARM)](#designed-and-tested-on-orange-pi-5-plus-arm)
- [JupyterHub components and kernels](#jupyterhub-components-and-kernels)
  - [System packages installed via apt](#system-packages-installed-via-apt)
  - [Python packages installed globally (pip)](#python-packages-installed-globally-pip)
  - [Python version management: pyenv](#python-version-management-pyenv)
  - [Creating virtual environments and adding kernels to JupyterHub](#creating-virtual-environments-and-adding-kernels-to-jupyterhub)
  - [Rust kernel (evcxr_jupyter)](#rust-kernel-evcxr_jupyter)
  - [Julia kernel (IJulia)](#julia-kernel-ijulia)
  - [R kernel (IRkernel)](#r-kernel-irkernel)
- [Adapting to x86_64 (Intel/AMD)](#adapting-to-x86_64-intelamd)
- [.env and .env.example](#env-file-and-envexample)
- [Security warning](#security-warning)
- [HOWTO: multi-arch and docker buildx](#howto-multi-arch-and-docker-buildx)
- [Contact](#contact)


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

JupyterHub components and kernels

This section documents the JupyterHub-related components installed by the `jupyterlab` Dockerfile and explains how to manage Python versions, virtual environments, and kernels.

System packages installed via apt

The Dockerfile installs a set of OS-level packages required for building and running many data-science tools. Main packages installed by `apt` include:

- curl, git, build-essential, cmake
- python3, python3-pip, python3-venv
- r-base, xz-utils
- clang
- sqlite3, tk-dev
- libsqlite3-dev, libncursesw5-dev
- libssl-dev
- libxml2-dev
- libcurl4-openssl-dev
- ca-certificates, nodejs, npm
- bash, nano, vim

These provide compilers, interpreters and development headers needed by R, Julia, Rust, and many Python packages.

Python packages installed globally (pip)

The Dockerfile installs a curated set of Python packages into the global Python environment (via pip). These are installed during image build and are available to all users unless overridden by environment-specific kernels:

- poetry, ipykernel
- numpy, pandas, scipy, polars
- matplotlib, seaborn, plotly, altair
- scikit-learn
- xgboost, catboost
- transformers, datasets, accelerate
- mlflow, boto3, wandb
- feature-engine, imbalanced-learn
- dask, pyarrow, duckdb
- tqdm, rich, ipywidgets
- tensorflow-aarch64, onnxruntime
- sentence-transformers
- fastparquet, numexpr
- optuna, jupyterhub
- torch (installed from PyTorch CPU index)

Additionally, Jupyter components are installed:

- jupyterlab, notebook, jupyter-client, jupyter-core

The image also installs `configurable-http-proxy` globally via npm (used by JupyterHub).

Python version management: pyenv

The image sets up `pyenv` at `/opt/pyenv` and installs Python 3.13.11, setting it as the global Python for the image:

- PYENV_ROOT=/opt/pyenv
- pyenv install 3.13.11
- pyenv global 3.13.11

This enables installing additional Python versions with `pyenv install <version>` and switching between them using `pyenv global|local|shell`.

Creating virtual environments and adding kernels to JupyterHub

Two common workflows are supported:

1) Using python -m venv (recommended, simple)

- Create a new virtualenv:

  python -m venv /opt/venvs/myenv
  source /opt/venvs/myenv/bin/activate
  pip install --upgrade pip
  pip install ipykernel [any other packages]

- Register the virtualenv as a Jupyter kernel (system-wide or for JupyterHub):

  For a user-local kernel:
  ```bash
  python -m ipykernel install --user --name myenv --display-name "Python (myenv)"
  ```

  For a system-wide kernel (requires root inside the container; installs to /usr/local/share/jupyter/kernels):
  ```bash
  python -m ipykernel install --name myenv --display-name "Python (myenv)" --sys-prefix
  ```

  Or explicitly to /usr/local/share/jupyter/kernels:
  ```bash
  python -m ipykernel install --prefix=/usr/local --name myenv --display-name "Python (myenv)"
  ```

2) Using pyenv (installing additional Python versions)

- Install a new Python version with pyenv:

  pyenv install 3.12.2
  pyenv virtualenv 3.12.2 myenv-3.12
  pyenv activate myenv-3.12

- Inside that environment install ipykernel and any packages, then register the kernel as above:

  pip install ipykernel
  python -m ipykernel install --name myenv-3.12 --display-name "Python (3.12 - myenv)" --sys-prefix

Note: if `pyenv virtualenv` is not available in the image, it can be added or `python -m venv` can be used after `pyenv install` by referring to the pyenv-managed interpreter path.

Rust kernel (evcxr_jupyter)

The Rust toolchain is installed using rustup (CARGO_HOME=/opt/cargo, RUSTUP_HOME=/opt/rustup). The Rust Jupyter kernel is installed via `evcxr_jupyter`:

- cargo install evcxr_jupyter
- evcxr_jupyter --install
- Kernel spec copied to /usr/local/share/jupyter/kernels/

This provides an interactive Rust kernel in Jupyter.

Julia kernel (IJulia)

Julia is installed with the official installer script. The Dockerfile then installs IJulia and common ML packages:

- julia -e 'using Pkg; Pkg.add(["IJulia","Flux","MLJ"])'
- Kernel specs are copied to /usr/local/share/jupyter/kernels/

R kernel (IRkernel)

R (r-base) is installed via apt and then the tidyverse and IRkernel packages are installed:

- R -e "install.packages(c('tidyverse','IRkernel'), repos='https://cloud.r-project.org')"
- R -e "IRkernel::installspec(user = FALSE)"  # installs kernel system-wide

Listing installed kernels

The Dockerfile runs `jupyter kernelspec list` to show available kernels after installation; you should see entries for python, julia, R and rust when the image build completes.

Best practices for adding kernels in JupyterHub

- For multi-user JupyterHub deployments, install kernels system-wide (use `--sys-prefix` or run install commands as root) so all users can access them.
- Prefer creating isolated virtual environments per project and register them as kernels rather than installing many packages into the global interpreter.
- Record the kernel display name clearly to indicate the Python version and purpose (e.g., "Python (3.13 - ml)" ).

Helper script: scripts/add_kernel.sh

A helper script has been added at `scripts/add_kernel.sh` to simplify creating a Python virtual environment, installing packages and registering an ipykernel. The script defaults to creating venvs under `/opt/venvs/<NAME>` and registers kernels with `--sys-prefix` (system-wide under the container) unless `--prefix` is passed.

Example - copy-and-run (recommended)

1) Copy the script from the repository into the running jupyterlab container and execute it (host shell):

```bash
# find container id (or use docker compose name)
CONTAINER=$(docker compose ps -q jupyterlab)
# copy script into container
docker cp ./scripts/add_kernel.sh ${CONTAINER}:/usr/local/bin/add_kernel.sh
# make it executable and run it inside the container as root
docker compose exec jupyterlab chmod +x /usr/local/bin/add_kernel.sh
docker compose exec jupyterlab /usr/local/bin/add_kernel.sh -n mlenv -r "numpy pandas scikit-learn" -d "Python (mlenv)"
```

2) One-off run mounting the scripts directory (no copy needed):

```bash
# from project root
docker compose run --rm -v "$(pwd)/scripts:/work/scripts" jupyterlab /work/scripts/add_kernel.sh -n mlenv -r "numpy pandas scikit-learn" -d "Python (mlenv)"
```

Using the JupyterHub terminal (in-browser)

If you have access to the JupyterHub terminal in the browser (Terminal tab), you can create or fetch the script from there and run it:

- Option A: paste the script content into a new file:

```bash
cat > /tmp/add_kernel.sh <<'SCRIPT'
# (paste the script contents here)
SCRIPT
chmod +x /tmp/add_kernel.sh
sudo /tmp/add_kernel.sh -n mlenv -r "numpy pandas scikit-learn" -d "Python (mlenv)"
```

- Option B: fetch the script directly if the repository is accessible via HTTP (raw URL):

```bash
curl -fsSL https://raw.githubusercontent.com/<user>/<repo>/main/scripts/add_kernel.sh -o /tmp/add_kernel.sh
chmod +x /tmp/add_kernel.sh
sudo /tmp/add_kernel.sh -n mlenv -r "numpy pandas scikit-learn" -d "Python (mlenv)"
```

Notes

- To make the kernel available to all Hub users register it with `--sys-prefix` (default in the helper) or use `--prefix=/usr/local`.
- Running the script as root inside the container ensures system-level installation; if you run it as a non-root user, consider `--user` kernel installs or installing into a shared directory.

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

Repository tree (English)

- docker-compose.yml (Docker Compose service/volume definitions)
- LICENSE (project license)
- HOWTO-multiarch.md (guide to build multi-architecture images with buildx)
- jupyterlab/ (JupyterHub/JupyterLab build context)
  - Dockerfile (instructions to build the JupyterLab/JupyterHub image)
  - jupyterhub_config.py (JupyterHub configuration used at container runtime)
- code-server/ (code-server build context)
  - Dockerfile (build for code-server / VS Code in the browser)
- marimo/ (auxiliary service context)
  - Dockerfile (build for marimo service)
- .env.example (example environment variables for docker-compose and builds)
- README.md (this documentation)

---

# ML Server — Data Lab para Machine Learning

Tabla de contenidos (Español)

- [Principales archivos y carpetas](#principales-archivos-y-carpetas)
- [Resumen arquitectural](#resumen-arquitectural)
- [Diseñado y probado en Orange Pi 5 Plus (ARM)](#diseñado-y-probado-en-orange-pi-5-plus-arm)
- [Componentes de JupyterHub y kernels](#componentes-de-jupyterhub-y-kernels)
  - [Paquetes del sistema (apt)](#paquetes-del-sistema-apt)
  - [Paquetes Python instalados globalmente (pip)](#paquetes-python-instalados-globalmente-pip)
  - [pyenv y gestión de versiones de Python](#pyenv-y-gestión-de-versiones-de-python)
  - [Crear entornos virtuales y añadir kernels](#crear-entornos-virtuales-y-añadir-kernels)
  - [Kernel de Rust (evcxr_jupyter)](#kernel-de-rust-evcxr_jupyter)
  - [Kernel de Julia (IJulia)](#kernel-de-julia-ijulia)
  - [Kernel de R (IRkernel)](#kernel-de-r-irkernel)
- [Adaptación a arquitecturas x86_64 (Intel/AMD)](#adaptación-a-arquitecturas-x86_64-intelamd)
- [Archivo .env y .env.example](#archivo-env-y-envexample)
- [Advertencia de seguridad](#advertencia-de-seguridad)
- [HOWTO: multi-arch y buildx](#howto-multi-arch-y-buildx)
- [Contacto](#contacto)


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

Componentes de JupyterHub y kernels

Esta sección documenta los componentes relacionados con JupyterHub instalados por el Dockerfile de `jupyterlab` y explica cómo gestionar versiones de Python, entornos virtuales y kernels.

Paquetes del sistema instalados vía apt

El Dockerfile instala un conjunto de paquetes a nivel OS necesarios para compilar y ejecutar muchas herramientas de ciencia de datos. Los paquetes principales instalados son:

- curl, git, build-essential, cmake
- python3, python3-pip, python3-venv
- r-base, xz-utils
- clang
- sqlite3, tk-dev
- libsqlite3-dev, libncursesw5-dev
- libssl-dev
- libxml2-dev
- libcurl4-openssl-dev
- ca-certificates, nodejs, npm
- bash, nano, vim

Estos proveen compiladores, intérpretes y headers de desarrollo necesarios por R, Julia, Rust y muchos paquetes Python.

Paquetes Python instalados globalmente (pip)

El Dockerfile instala un conjunto predefinido de paquetes Python en el entorno global. Estos están disponibles para todos los usuarios en la imagen:

- poetry, ipykernel
- numpy, pandas, scipy, polars
- matplotlib, seaborn, plotly, altair
- scikit-learn
- xgboost, catboost
- transformers, datasets, accelerate
- mlflow, boto3, wandb
- feature-engine, imbalanced-learn
- dask, pyarrow, duckdb
- tqdm, rich, ipywidgets
- tensorflow-aarch64, onnxruntime
- sentence-transformers
- fastparquet, numexpr
- optuna, jupyterhub
- torch (instalado desde el índice CPU de PyTorch)

Además se instalan componentes de Jupyter:

- jupyterlab, notebook, jupyter-client, jupyter-core

También se instala `configurable-http-proxy` globalmente vía npm (usado por JupyterHub).

Gestión de versiones de Python: pyenv

La imagen configura `pyenv` en `/opt/pyenv` e instala Python 3.13.11, configurándolo como la versión global:

- PYENV_ROOT=/opt/pyenv
- pyenv install 3.13.11
- pyenv global 3.13.11

Esto permite instalar versiones adicionales con `pyenv install <version>` y cambiar entre ellas con `pyenv global|local|shell`.

Crear entornos virtuales y añadir kernels a JupyterHub

Flujos de trabajo recomendados:

1) Usando python -m venv (recomendado y sencillo)

- Crear un virtualenv:

  python -m venv /opt/venvs/mienv
  source /opt/venvs/mienv/bin/activate
  pip install --upgrade pip
  pip install ipykernel [otros paquetes]

- Registrar el virtualenv como kernel en Jupyter (local o sistema):

  Para un kernel local de usuario:
  ```bash
  python -m ipykernel install --user --name mienv --display-name "Python (mienv)"
  ```

  Para un kernel a nivel sistema (requiere root dentro del contenedor; instalará en /usr/local/share/jupyter/kernels):
  ```bash
  python -m ipykernel install --name mienv --display-name "Python (mienv)" --sys-prefix
  ```

  O explícitamente en /usr/local/share/jupyter/kernels:
  ```bash
  python -m ipykernel install --prefix=/usr/local --name mienv --display-name "Python (mienv)"
  ```

Script helper: scripts/add_kernel.sh (uso en la práctica)

Se añadió un script helper en `scripts/add_kernel.sh` para simplificar la creación de virtualenvs, instalación de paquetes y registro de ipykernels. Por defecto crea los entornos en `/opt/venvs/<NAME>` y registra el kernel con `--sys-prefix`.

Ejemplo - copiar y ejecutar desde el host (recomendado):

```bash
CONTAINER=$(docker compose ps -q jupyterlab)
docker cp ./scripts/add_kernel.sh ${CONTAINER}:/usr/local/bin/add_kernel.sh
docker compose exec jupyterlab chmod +x /usr/local/bin/add_kernel.sh
docker compose exec jupyterlab /usr/local/bin/add_kernel.sh -n mienv -r "numpy pandas scikit-learn" -d "Python (mienv)"
```

Ejemplo - ejecución one-off montando el directorio scripts:

```bash
# desde la raíz del proyecto
docker compose run --rm -v "$(pwd)/scripts:/work/scripts" jupyterlab /work/scripts/add_kernel.sh -n mienv -r "numpy pandas scikit-learn" -d "Python (mienv)"
```

Usando la terminal de JupyterHub (en el navegador):

- Opción A: crear y pegar el script directamente en la terminal:

```bash
cat > /tmp/add_kernel.sh <<'SCRIPT'
# (pega aquí el contenido del script)
SCRIPT
chmod +x /tmp/add_kernel.sh
sudo /tmp/add_kernel.sh -n mienv -r "numpy pandas scikit-learn" -d "Python (mienv)"
```

- Opción B: descargarlo si el repositorio es accesible públicamente (raw URL):

```bash
curl -fsSL https://raw.githubusercontent.com/<usuario>/<repo>/main/scripts/add_kernel.sh -o /tmp/add_kernel.sh
chmod +x /tmp/add_kernel.sh
sudo /tmp/add_kernel.sh -n mienv -r "numpy pandas scikit-learn" -d "Python (mienv)"
```

Notas:

- Para que el kernel sea visible por todos los usuarios registra con `--sys-prefix` (comportamiento por defecto del helper) o usa `--prefix=/usr/local`.
- Ejecutar el script como root dentro del contenedor asegura instalación a nivel sistema; si se ejecuta como usuario no-root, usar instalaciones de usuario o rutas compartidas.

2) Usando pyenv (instalar versiones adicionales)

- Instalar una versión con pyenv:

  pyenv install 3.12.2
  pyenv virtualenv 3.12.2 mienv-3.12
  pyenv activate mienv-3.12

- Dentro del entorno instalar ipykernel y registrar el kernel como arriba:

  pip install ipykernel
  python -m ipykernel install --name mienv-3.12 --display-name "Python (3.12 - mienv)" --sys-prefix

Nota: si `pyenv virtualenv` no está disponible, puede añadirse o pueden usarse `python -m venv` apuntando al intérprete administrado por pyenv.

Kernel de Rust (evcxr_jupyter)

La toolchain Rust se instala con rustup (CARGO_HOME=/opt/cargo, RUSTUP_HOME=/opt/rustup). El kernel Rust se instala con `evcxr_jupyter`:

- cargo install evcxr_jupyter
- evcxr_jupyter --install
- El kernelspec se copia a /usr/local/share/jupyter/kernels/

Esto proporciona un kernel interactivo de Rust en Jupyter.

Kernel de Julia (IJulia)

Julia se instala con el instalador oficial y luego se añaden paquetes útiles para ML:

- julia -e 'using Pkg; Pkg.add(["IJulia","Flux","MLJ"])'
- Los kernels se copian a /usr/local/share/jupyter/kernels/

Kernel de R (IRkernel)

R se instala via apt y luego se instalan tidyverse e IRkernel:

- R -e "install.packages(c('tidyverse','IRkernel'), repos='https://cloud.r-project.org')"
- R -e "IRkernel::installspec(user = FALSE)"  # instala kernel a nivel sistema

Listado de kernels instalados

El Dockerfile ejecuta `jupyter kernelspec list` para mostrar los kernels disponibles tras la instalación; deberías ver python, julia, R y rust cuando la build finalice.

Buenas prácticas para añadir kernels en JupyterHub

- Para despliegues multi-usuario de JupyterHub, instala kernels a nivel sistema (usar `--sys-prefix` o ejecutar como root) para que todos los usuarios los vean.
- Prefiere crear entornos virtuales aislados por proyecto y registrarlos como kernels en lugar de instalar muchos paquetes en el intérprete global.
- Etiqueta el display name indicando la versión de Python y el propósito (por ejemplo: "Python (3.13 - ml)").

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

Árbol del repositorio (español)

- docker-compose.yml (definición de servicios y volúmenes para docker-compose)
- LICENSE (licencia del proyecto)
- HOWTO-multiarch.md (guía para construir imágenes multi-arquitectura con buildx)
- jupyterlab/ (contexto de construcción de JupyterHub/JupyterLab)
  - Dockerfile (instrucciones para construir la imagen de JupyterLab/JupyterHub)
  - jupyterhub_config.py (configuración de JupyterHub usada en tiempo de ejecución)
- code-server/ (contexto de construcción de code-server)
  - Dockerfile (build para code-server / VS Code en el navegador)
- marimo/ (contexto del servicio auxiliar)
  - Dockerfile (build para el servicio marimo)
- .env.example (archivo ejemplo con variables de entorno para docker-compose y builds)
- README.md (esta documentación)

