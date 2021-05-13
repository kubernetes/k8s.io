#/bin/bash

# dependencies: parallel, grep

BASE="us.gcr.io/k8s-artifacts-prod/"

for ARG in $*
do
    echo "===="
    echo "Layer:"$ARG
    echo "Repos"
    declare -a MATCH_REPO=()
    MATCH_REPO+=$(find repos -type f | cut -d "/" -f2- <<< $(parallel -k -j1000% -n 1000 -m grep -H -l -m1 $ARG {}))
    IFS=$'\n' MATCH_REPO_SORTED=($(sort <<<"${MATCH_REPO[*]}"))
    unset IFS
    for V in "${MATCH_REPO_SORTED[@]}"
    do
        V=${V//\_/\/}
        V=${V#"$BASE"}
        echo "  "$V
    done
    echo ""
    echo "Tags"
    declare -a MATCH_TAG=()
    MATCH_TAG+=$(find tags -type f | cut -d "/" -f2- <<< $(parallel -k -j1000% -n 1000 -m grep -H -l -m1 $ARG {}))
    IFS=$'\n' MATCH_TAG_SORTED=($(sort <<<"${MATCH_TAG[*]}"))
    unset IFS
    for V in "${MATCH_TAG_SORTED[@]}"
    do
       V=${V//\_/\/}
       V=${V#"$BASE"}
       echo "  "$V
    done
    echo ""
done
