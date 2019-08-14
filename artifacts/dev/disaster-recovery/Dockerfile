FROM debian:stretch

RUN apt-get update && apt-get install --yes python3 python3-pip

# Not available as a package?
RUN pip3 install google-cloud-storage==1.18.0

ADD copy-buckets.py /copy-buckets.py

ENTRYPOINT ["/copy-buckets.py"]
