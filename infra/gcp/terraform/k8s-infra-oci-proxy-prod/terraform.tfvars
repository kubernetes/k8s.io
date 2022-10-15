/*
Copyright 2022 The Kubernetes Authors.

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

domain     = "registry.k8s.io"
project_id = "k8s-infra-oci-proxy-prod"
digest     = "sha256:fc811af33c78e9765ee95d6994a6e0dac4c382ae63a960872404b7190110c769"
cloud_run_config = {
  asia-east1 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://asia-east1-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  asia-northeast1 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://asia-northeast1-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  asia-northeast2 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://asia-northeast2-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  asia-south1 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://asia-south1-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  australia-southeast1 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://australia-southeast1-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  europe-north1 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://europe-north1-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  europe-southwest1 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://europe-southwest1-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  europe-west1 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://europe-west1-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  europe-west2 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://europe-west2-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  europe-west4 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://europe-west4-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  europe-west8 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://europe-west8-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  europe-west9 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://europe-west9-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  southamerica-west1 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://southamerica-west1-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  us-central1 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://us-central1-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  us-east1 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://us-east1-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  us-east4 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://us-east4-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  us-east5 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://us-east5-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  us-south1 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://us-south1-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  us-west1 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://us-west1-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
  us-west2 = {
    environment_variables = [
      {
        name  = "UPSTREAM_REGISTRY_ENDPOINT",
        value = "https://us-west2-docker.pkg.dev"
      },
      {
        name  = "UPSTREAM_REGISTRY_PATH",
        value = "k8s-artifacts-prod/images"
      }
    ]
  }
}
