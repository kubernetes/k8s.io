# Copyright 2023 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/usr/bin/env bash
set -xeuo pipefail

# TODO(pkprzekwas): point at k8s.io main
github_org=pkprzekwas
github_repo=k8s.io
github_branch=eks-prow-build-cluster-gitops

if ! command -v flux &> /dev/null
then
  echo "flux could not be found"
  exit 2
fi

hack_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

function boilerplate() {
  cat ${hack_dir}/../../../../../hack/boilerplate/boilerplate.sh.txt | sed -e "s/\<YEAR\>/$(date +'%Y')/"
}

resources_dir=${hack_dir}/../resources

# Generate all Flux resources (gotk - GitOpsToolKit)
boilerplate > ${resources_dir}/flux-system/gotk-components.yaml
flux install --export >> ${resources_dir}/flux-system/gotk-components.yaml

boilerplate > ${resources_dir}/flux-system/git-source-k8s.io.yaml
flux create source git k8s-io \
  --url=https://github.com/${github_org}/k8s.io \
  --branch=${github_branch} \
  --interval=5m \
  --export >> ${resources_dir}/flux-system/git-source-k8s.io.yaml

boilerplate > ${resources_dir}/flux-system/helm-source-eks-charts.yaml
flux create source helm eks-charts \
  --url=https://aws.github.io/eks-charts \
  --interval=5m \
  --export >> ${resources_dir}/flux-system/helm-source-eks-charts.yaml

boilerplate > ${resources_dir}/kube-system/flux-hr-node-termination-handler.yaml
flux create hr node-termination-handler \
    --source=HelmRepository/eks-charts.flux-system \
    --namespace=kube-system \
    --chart=aws-node-termination-handler \
    --chart-version=0.21.0 \
    --interval=5m \
    --export >> ${resources_dir}/kube-system/flux-hr-node-termination-handler.yaml

kustomizations=(
    boskos
    flux-system
    kube-system
    monitoring
    node-problem-detector
    rbac
    test-pods
)

pushd ${resources_dir} > /dev/null
resources_in_repo_path=$(git rev-parse --show-prefix)

for k in "${kustomizations[@]}"; do
    boilerplate > ${resources_dir}/flux-system/ks-${k}.yaml
    flux create kustomization ${k} \
        --source=GitRepository/k8s-io.flux-system \
        --path=${resources_in_repo_path}/${k} \
        --interval=5m \
        --export >> ${resources_dir}/flux-system/ks-${k}.yaml
done

popd > /dev/null
