FROM codercom/code-server:latest

USER root

RUN apt update && sudo apt install -y \
    python3 python3-pip \
    git \
    curl bash build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libffi-dev \
    liblzma-dev && sudo rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://pyenv.run -o pyenv.sh \
    && chmod +x pyenv.sh \
    && sudo ./pyenv.sh -y \
    && rm pyenv.sh

ENV PYENV_ROOT="/root/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"


RUN pyenv install 3.13.0
RUN pyenv global 3.13.0

RUN pip install \
    poetry \
    mlflow \
    jupyterlab

EXPOSE 8080