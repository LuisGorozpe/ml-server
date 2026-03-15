FROM python:3.11

RUN pip install \
    marimo \
    pandas \
    numpy \
    matplotlib \
    mlflow

EXPOSE 2718

CMD ["marimo", "edit", "--host", "0.0.0.0"]