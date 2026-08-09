# FROM debian:bookworm-slim (uncoment  this line to build for amd64)
# FROM arm64v8/debian:stable
FROM ophub/armbian-bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    curl git build-essential cmake \
    python3 python3-pip python3-venv \
    r-base xz-utils \
    clang \
    sqlite3 tk-dev \
    libsqlite3-dev libncursesw5-dev\
    libssl-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    ca-certificates nodejs npm \
    build-essential bash nano vim \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://install.julialang.org -o install-julia.sh \
    && chmod +x install-julia.sh \
    && ./install-julia.sh -y \
    && rm install-julia.sh

ENV CARGO_HOME=/opt/cargo RUSTUP_HOME=/opt/rustup

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o rustup.sh \
    && chmod +x rustup.sh \
    && ./rustup.sh -y \
    && rm rustup.sh

ENV PATH="/opt/cargo/bin:${PATH}"
#ENV PATH="/root/.cargo/bin:${PATH}"

# -----------------
# Python env
# -----------------

RUN curl -fsSL https://pyenv.run -o pyenv.sh \
    && chmod +x pyenv.sh \
    && ./pyenv.sh -y \
    && rm pyenv.sh

ENV PYENV_ROOT=/opt/pyenv
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

RUN pyenv install 3.13.11
RUN pyenv global 3.13.11

ENV PATH="/opt/pyenv/versions/3.13.11/bin:${PATH}"
# -----------------
# JupyterLab
# -----------------

RUN pip install --no-cache-dir \
    poetry ipykernel \
    numpy pandas scipy polars \
    matplotlib seaborn plotly altair \
    scikit-learn \
    xgboost catboost \
    transformers datasets accelerate \
    mlflow boto3 wandb \
    feature-engine imbalanced-learn \
    dask pyarrow duckdb \
    tqdm rich ipywidgets \
    tensorflow-aarch64 onnxruntime \
    sentence-transformers \
    fastparquet numexpr \
    optuna jupyterhub

RUN pip install --no-cache-dir \
    --index-url https://download.pytorch.org/whl/cpu \
    torch

RUN npm install -g configurable-http-proxy

RUN pip install --no-cache-dir jupyterlab notebook \
    jupyter-client \
    jupyter-core 

# -----------------
# R packages
# -----------------
RUN mkdir -p /usr/local/share/jupyter/kernels

RUN R -e "install.packages(c('tidyverse','IRkernel'), repos='https://cloud.r-project.org')"

RUN R -e "IRkernel::installspec(user = FALSE)"

# -----------------
# Julia packages
# -----------------

ENV PATH="/root/.juliaup/bin:${PATH}"
ENV JULIA_DEPOT_PATH=/opt/julia-depot

RUN julia -e 'using Pkg; Pkg.add(["IJulia","Flux","MLJ"])' \
&& cp -r /root/.local/share/jupyter/kernels/julia-* /usr/local/share/jupyter/kernels/

# -----------------
# Rust kernel
# -----------------
RUN useradd -m -s /bin/bash datalab && echo 'datalab:datalab' | chpasswd

RUN cargo install evcxr_jupyter
RUN evcxr_jupyter --install \ 
&& cp -r /root/.local/share/jupyter/kernels/rust /usr/local/share/jupyter/kernels/

RUN jupyter kernelspec list

# -----------------
# JupyterHub: usuario, config y arranque
# -----------------

#RUN mkdir -p /etc/jupyterhub
#RUN jupyterhub --generate-config -f /etc/jupyterhub/jupyterhub_config.py
RUN mkdir -p /etc/jupyterhub /srv/jupyterhub
COPY jupyterhub_config.py /etc/jupyterhub/jupyterhub_config.py
WORKDIR /srv/jupyterhub

EXPOSE 8888

#CMD ["jupyter", "lab", "--ip=0.0.0.0", "--allow-root"]
CMD ["jupyterhub", "-f", "/etc/jupyterhub/jupyterhub_config.py"]