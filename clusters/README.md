# clusters

This directory contains Terraform cluster configurations for the various GCP
projects that the Kubernetes project maintains.

Each directory (other than `image`) is a standalone Terraform configuration. We
may template these into modules at some point, but for now they are designed to
be straight forward and verbose. 
