# FROM debian:bookworm-slim (uncoment  this line to build for amd64)
# FROM arm64v8/debian:stable
FROM ophub/armbian-bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    curl git build-essential cmake \
    python3 python3-pip python3-venv \
    r-base \
    clang \
    libssl-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    ca-certificates \
    build-essential bash \
     && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://install.julialang.org -o install-julia.sh \
    && chmod +x install-julia.sh \
    && ./install-julia.sh -y \
    && rm install-julia.sh

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o rustup.sh \
    && chmod +x rustup.sh \
    && ./rustup.sh -y \
    && rm rustup.sh
    
ENV PATH="/root/.cargo/bin:${PATH}"

# -----------------
# Python env
# -----------------

RUN curl -fsSL https://pyenv.run -o pyenv.sh \
    && chmod +x pyenv.sh \
    && ./pyenv.sh -y \
    && rm pyenv.sh

ENV PYENV_ROOT="/root/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

RUN pyenv install 3.13.11
RUN pyenv global 3.13.11
# -----------------
# JupyterLab
# -----------------

RUN pip install --no-cache-dir \
    poetry jupyterlab \
    jupyter-client \
    jupyter-core \
    ipykernel \
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
    optuna

RUN pip install --no-cache-dir \
    --index-url https://download.pytorch.org/whl/cpu \
    torch

# -----------------
# R packages
# -----------------

RUN R -e "install.packages(c('tidyverse','IRkernel'), repos='https://cloud.r-project.org')"

RUN jupyter kernelspec list

RUN R -e "IRkernel::installspec(user = FALSE)"

# -----------------
# Julia packages
# -----------------
ENV PATH="/root/.juliaup/bin:${PATH}"

RUN julia -e 'using Pkg; Pkg.add(["IJulia","Flux","MLJ"])'

# -----------------
# Rust kernel
# -----------------

RUN cargo install evcxr_jupyter
RUN evcxr_jupyter --install


EXPOSE 8888

CMD ["jupyter", "lab", "--ip=0.0.0.0", "--allow-root"]