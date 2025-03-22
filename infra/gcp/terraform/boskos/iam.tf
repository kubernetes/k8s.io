/*
Copyright 2025 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

# We grant all the boskos permissions on the folder and they get inherited
module "folder_iam" {
  source  = "terraform-google-modules/iam/google//modules/folders_iam"
  version = "~> 8.1"
  folders = [google_folder.boskos.id]
  mode    = "authoritative"

  bindings = {
    "organizations/758905017065/roles/prow.viewer" : [
      "group:k8s-infra-prow-viewers@kubernetes.io"
    ]
    "roles/cloudkms.admin" = [
      "serviceAccount:prow-build@k8s-infra-prow-build.iam.gserviceaccount.com"
    ]
    "roles/cloudkms.cryptoKeyEncrypterDecrypter" = [
      "serviceAccount:prow-build@k8s-infra-prow-build.iam.gserviceaccount.com"
    ]
    "roles/editor" = [
      "serviceAccount:boskos-janitor@k8s-infra-prow-build.iam.gserviceaccount.com",
      "serviceAccount:prow-build@k8s-infra-prow-build.iam.gserviceaccount.com"
    ]
    "roles/owner" = [
      "group:k8s-infra-prow-oncall@kubernetes.io"
    ]
    "roles/iam.serviceAccountUser" = [
      "serviceAccount:prow-build@k8s-infra-prow-build.iam.gserviceaccount.com"
    ]
    "roles/secretmanager.admin" = [
      "serviceAccount:prow-build@k8s-infra-prow-build.iam.gserviceaccount.com"
    ]
  }

}
