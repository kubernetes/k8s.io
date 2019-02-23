#!/bin/sh

set -o errexit
set -o nounset
set -o pipefail

usage()
{
    echo >&2 "usage: $0 <path/to/cip/binary> [<path/to/manifest.yaml>,<path/to/service-account.json>, ...]"
    echo >&2 "The 2nd argument onwards are '<manifest>,<service-account>' pairs."
    echo >&2
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

cip="$1"
shift

for opts in "$@"; do
    manifest=$(echo "$opts" | cut -d, -f1)
    service_account_creds=$(echo "$opts" | cut -d, -f2)

    # Authenticate as the service account. This allows the promoter to later
    # call gcloud with the flag `--account=...`. We can allow the service
    # account creds file to be empty, for testing cip locally (for the case
    # where the service account creds are already activated).
    if [ -f "${service_account_creds}" ]; then
        gcloud auth activate-service-account --key-file="${service_account_creds}"
    fi

    # Run the promoter against the manifest.
    "${cip}" -verbosity=3 -manifest="${manifest}" ${CIP_OPTS:+$CIP_OPTS}
done
