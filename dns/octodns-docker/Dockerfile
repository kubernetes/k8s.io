# python:2-alpine as of March 26th, 2019
ARG BASE_IMAGE=python@sha256:46d6e67d464a2811efe60440248623b14cb6db273fac59631dd8bd9e13a77491
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
