# python:2-alpine as of October 29th, 2018
ARG BASE_IMAGE=python@sha256:6f7386fb948e2c209bbf1a2b18fd6af060d1f453006cbcb0b43d6bca6ba2a364
FROM ${BASE_IMAGE}

# install from requirements.txt and ensure that all requirements match
# pip freeze after, guaranteeing that we will install the same packages if we
# build again
COPY requirements.txt /requirements.txt
RUN pip install -r /requirements.txt && \
    echo "freezing deps, please make sure requirements.txt matches" && \
    pip freeze | tee /newrequirements.txt && \
    diff /requirements.txt /newrequirements.txt
# RUN pip install ipython ipdb
# RUN apk add bash
COPY check-zone.py /usr/local/bin/check-zone
CMD /bin/sh
