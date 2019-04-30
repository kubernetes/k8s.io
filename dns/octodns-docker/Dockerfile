# python:2-alpine as of April 30th, 2019
ARG BASE_IMAGE=python@sha256:20ecc1d602d2993516daa9c480d42ee6c99c61a4fdd3f646991247e69c1c12cb
FROM ${BASE_IMAGE}

# install from requirements.txt and ensure that all requirements match
# pip freeze after, guaranteeing that we will install the same packages if we
# build again
COPY requirements.txt /requirements.txt
RUN pip install -r /requirements.txt && \
    echo "freezing deps, please make sure requirements.txt matches" && \
    pip freeze | tee /newrequirements.txt && \
    diff /requirements.txt /newrequirements.txt
# To enable debugging:
# RUN pip install ipython ipdb
# pair with the following at breakpoints in python code:
# import ipdb ; ipdb.set_trace()
COPY check-zone.py /usr/local/bin/check-zone
CMD /bin/sh
