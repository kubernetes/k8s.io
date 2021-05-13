#!/bin/bash

# dependencies: gcrane, parallel, gcloud

# Note: Exporting arrays isn't possible therefore the array PLATFORMS is given as an argument
# Also used for BASE

PLATFORMS=( "linux/amd64" )
#PLATFORMS=( "linux/amd64" "linux/arm" "linux/arm64" "linux/ppc64le" "linux/s390x" )

BASE="us.gcr.io/k8s-artifacts-prod"

function repo_ls() {
    BASE=$1
    PLATFORMS=$2
    FQ_REPO=$3
    REPO=${FQ_REPO#"$BASE/"}
    FILE_REPO=$(cut -d ":" -f1 <<< $REPO)
    FILE_REPO=${FILE_REPO//\//\_}
    if [[ $FQ_REPO != *@sha256* ]]; then
        for PLATFORM in "${PLATFORMS[@]}"
        do
            FILE_TAG=${REPO//\//\_}_$(cut -d "/" -f2- <<< $PLATFORM)
            TAG=$(cut -d ":" -f2- <<< $FQ_REPO)
            RESP=$(gcrane manifest $FQ_REPO --platform $PLATFORM 2> /dev/null)
            RESULT=$?
            if [ $RESULT -eq 0 ]; then
                echo $RESP >> repos/$FILE_REPO
                echo $RESP >> tags/$FILE_TAG
                #echo "$REPO saved to $FILE_REPO and $FILE_TAG"
            else
                echo "$PLATFORM for $FQ_REPO not available"
            fi
        done
        # Platform specific errors not considered
        echo "$FQ_REPO saved to $FILE_REPO and tag files"
    fi
}

export -f repo_ls

echo "Cleanup repo and tag data"
rm -r repos
rm -r tags
mkdir -p repos
mkdir -p tags
echo "Iterate over using recursive ls and store repo and tag data"
LIST=$(gcrane ls -r $BASE)
# Note: With more platforms 4000% per core might be too aggressive - 400% should work
printf '%s\n' "${LIST[@]}" | parallel -j4000% -k --eta repo_ls $BASE $PLATFORMS {}
