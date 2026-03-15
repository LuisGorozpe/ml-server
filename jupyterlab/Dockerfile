FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    curl git build-essential cmake \
    python3 python3-pip python3-venv \
    r-base \
    julia \
    rustc cargo \
    clang \
    libssl-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    nodejs npm

# -----------------
# JupyterLab
# -----------------

RUN pip install jupyterlab

# -----------------
# Python env
# -----------------

RUN pip install pyenv poetry

RUN pip install \
    torch torchvision torchaudio \
    tensorflow \
    mlflow \
    ipykernel

# -----------------
# R packages
# -----------------

RUN R -e "install.packages(c('tidyverse','IRkernel'))"
RUN R -e "IRkernel::installspec()"

# -----------------
# Julia packages
# -----------------

RUN julia -e 'using Pkg; Pkg.add(["IJulia","Flux","MLJ"])'

# -----------------
# Rust kernel
# -----------------

RUN cargo install evcxr_jupyter
RUN evcxr_jupyter --install

# -----------------
# C++ kernel
# -----------------

RUN pip install xeus-cling

# -----------------
# MLflow
# -----------------

RUN pip install mlflow boto3

EXPOSE 8888

CMD ["jupyter", "lab", "--ip=0.0.0.0", "--allow-root"]