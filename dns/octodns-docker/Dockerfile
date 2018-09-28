# python:2-alpine as of September 14th, 2018
ARG BASE_IMAGE=python@sha256:222800bfb2b447212dcc1518b2dff8042de1207090b566893f63c1fa165c8f3e
FROM ${BASE_IMAGE}

# install from requirements.txt and ensure that all requirements match
# pip freeze after, guaranteeing that we will install the same packages if we
# build again
COPY requirements.txt /requirements.txt
RUN pip install -r /requirements.txt && \
    echo "freezing deps, please make sure requirements.txt matches" && \
    pip freeze | tee /newrequirements.txt && \
    diff /requirements.txt /newrequirements.txt

CMD /bin/sh
