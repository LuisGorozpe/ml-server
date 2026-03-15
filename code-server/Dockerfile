FROM codercom/code-server:latest

RUN sudo apt update && sudo apt install -y \
    python3 python3-pip \
    git \
    curl

RUN pip install \
    poetry \
    mlflow \
    jupyterlab

EXPOSE 8080