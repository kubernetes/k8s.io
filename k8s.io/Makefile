all: test

.PHONY: deploy-fake-secret
deploy-fake-secret:
	openssl genrsa -out tls.key 2048
	openssl req -new -key tls.key -out tls.csr -subj '/CN=k8s.io/O=TEST/C=US'
	openssl x509 -req -days 10000 -in tls.csr -signkey tls.key -out tls.crt
	kubectl get secret/ssl || kubectl create secret generic ssl --from-file=tls.key=tls.key --from-file=tls.crt=tls.crt

.PHONY: deploy
deploy:
	kubectl get secret/ssl || kubectl apply -f secret-ssl.yaml
	kubectl apply -f configmap-nginx.yaml
	kubectl apply -f configmap-www-get.yaml
	kubectl apply -f configmap-www-golang.yaml
	kubectl apply -f service-dev.yaml
	kubectl apply -f deployment.yaml

.PHONY: test
test:
	python test.py -q
