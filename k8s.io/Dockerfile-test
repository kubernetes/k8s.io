FROM python:2
MAINTAINER Jeff Grafton <jgrafton@google.com>

WORKDIR /workspace

RUN pip install pyyaml

COPY test.py configmap-*.yaml /workspace/

ENTRYPOINT /workspace/test.py
