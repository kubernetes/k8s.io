all: test

.PHONY: test
test:
	./test.py -q

.PHONY: docker-test
docker-test:
	docker build -t k8s-io-test -f Dockerfile-test .
	docker run -it --rm -e TARGET_IP=${TARGET_IP} k8s-io-test
