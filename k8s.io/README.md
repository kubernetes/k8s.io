Overview
====
This contains the Nginx configuration for k8s.io and the associated subdomain
redirectors.

Testing
====
Configure kubectl to target a test cluster on GKE.

Run `make deploy-fake-secret deploy` and wait for the service to be available--
the load balancer may take some time to configure.

Set `TARGET_IP` to the ingress IP of the running service:

    export TARGET_IP=$(kubectl get svc k8s-io '--template={{range .status.loadBalancer.ingress}}{{.ip}}{{end}}')

Use `make test` to run unit tests to verify the various endpoints on the server.

Deploying
===
Set kubectl to target the production cluster, then run `make deploy`.
