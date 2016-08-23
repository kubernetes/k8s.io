Overview
====
This contains the Nginx configuration for k8s.io and the associated subdomain
redirectors.

Testing
====
Configure kubectl to target a test cluster on GKE.

Run `make deploy-fake-secret deploy` and wait for the service to be available--
the load balancer may take some time to configure.

Use `make test` to run unit tests to verify the various endpoints on the server.

Deploying
===
Set kubectl to target the production cluster, then run `make deploy`.
