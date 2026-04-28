# codesearch

Images associated with the `codesearch` app hosted on https://cs.k8s.io

## cs-fetch-repos

Utility python script that runs as an `initContainer` for the **codesearch** application (aka Hound). 

This script generates the `/data/config.json` file that configures the git repos for codesearch to index. 