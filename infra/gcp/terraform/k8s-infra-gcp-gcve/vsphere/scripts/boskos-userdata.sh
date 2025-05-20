#!/bin/bash

function printProjectUserData() {
  NR="${1}"

  S2="$(($(($(($NR-1))*16))))"
  E2="$(($(($NR*16))-1))"

  S1="$((${S2}/256))"
  E1="$((${E2}/256))"
  S2="$((${S2}%256))"
  E2="$((${E2}%256))"

  START="192.168.$((33+$S1)).${S2}"
  END="192.168.$((33+$E1)).${E2}"

  printf "k8s-infra-e2e-gcp-gcve-project-%03d:\n" "${NR}"
  printf "  folder: /Datacenter/vm/prow/k8s-infra-e2e-gcp-gcve-project-%03d\n" "${NR}"
  printf "  resourcePool: /Datacenter/host/k8s-gcve-cluster/Resources/prow/k8s-infra-e2e-gcp-gcve-project-%03d\n" "${NR}"
  printf "  ipPool: '{\\\"addresses\\\":[\\\"%s-%s\\\"],\\\"gateway\\\":\\\"192.168.32.1\\\",\\\"prefix\\\":21}'\n" "${START}" "${END}"
}

for i in {1..40}; do
  printProjectUserData "${i}"
done