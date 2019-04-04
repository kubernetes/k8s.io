all: test


.PHONY: deploy
deploy:
	kubectl apply -f configmap-nginx.yaml
	kubectl apply -f configmap-www-get.yaml
	kubectl apply -f service-dev.yaml
	kubectl apply -f deployment.yaml
	kubectl apply -f certificate-dev.yaml
	kubectl apply -f ingress-dev.yaml

.PHONY: test
test:
	python test.py -q

.PHONY: docker-test
docker-test:
	docker build -t k8s-io-test -f Dockerfile-test .
	docker run -it --rm -e TARGET_IP=${TARGET_IP} k8s-io-test
