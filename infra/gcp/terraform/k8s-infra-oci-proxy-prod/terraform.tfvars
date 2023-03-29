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
// gcr.io/k8s-staging-infra-tools/archeio:v20230310-v0.2.0@sha256:bc742c5f47a69e21e828768991853faddbe13a7f69a9da4d7d2ad16e0e55892c
// If you're interested in running this image yourself releases are available at registry.k8s.io/infra-tools/archeio
digest = "sha256:bc742c5f47a69e21e828768991853faddbe13a7f69a9da4d7d2ad16e0e55892c"
// we increase this in staging, but not in production
// we already get a lot of info from build-in cloud run logs
verbosity = "0"
cloud_run_config = {
  asia-east1 = {
    // TODO: switch DEFAULT_AWS_BASE_URL to cloudfront or else refine the region mapping
    // GCP asia-east1 is Changhua County, Taiwan
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS ap-southeast-1 is Singapore
        value = "https://prod-registry-k8s-io-ap-southeast-1.s3.dualstack.ap-southeast-1.amazonaws.com",
      },
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
  // GCP asia-northeast1 is Tokyo, Japan
  asia-northeast1 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS ap-northeast-1 is Tokyo
        value = "https://prod-registry-k8s-io-ap-northeast-1.s3.dualstack.ap-northeast-1.amazonaws.com",
      },
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
  // GCP asia-northeast2 is Osaka, Japan
  asia-northeast2 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS ap-northeast-1 is Tokyo
        value = "https://prod-registry-k8s-io-ap-northeast-1.s3.dualstack.ap-northeast-1.amazonaws.com",
      },
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
  // GCP asia-south1 is Mumbai, India
  asia-south1 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS ap-south-1 is Mumbai
        value = "https://prod-registry-k8s-io-ap-south-1.s3.dualstack.ap-south-1.amazonaws.com",
      },
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
  // GCP australia-southeast1 is Sydney
  australia-southeast1 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS ap-southeast-1 is Singapore
        value = "https://prod-registry-k8s-io-ap-southeast-1.s3.dualstack.ap-southeast-1.amazonaws.com",
      },
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
  // GCP europe-north1 is Hamina, Finland
  europe-north1 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS eu-central-1 is Frankfurt
        value = "https://prod-registry-k8s-io-eu-central-1.s3.dualstack.eu-central-1.amazonaws.com",
      },
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
  // GCP europe-southwest1 is Madrid, Spain
  europe-southwest1 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS eu-central-1 is Frankfurt
        value = "https://prod-registry-k8s-io-eu-central-1.s3.dualstack.eu-central-1.amazonaws.com",
      },
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
  // GCP europe-west1 is St. Ghislain, Belgium
  europe-west1 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS eu-central-1 is Frankfurt
        value = "https://prod-registry-k8s-io-eu-central-1.s3.dualstack.eu-central-1.amazonaws.com",
      },
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
  // GCP europe-west2 is London, UK
  europe-west2 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS eu-west-2 is London
        value = "https://prod-registry-k8s-io-eu-west-2.s3.dualstack.eu-west-2.amazonaws.com",
      },
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
  // GCP europe-west4 is Eemshaven, Netherlands
  europe-west4 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS eu-central-1 is Frankfurt
        value = "https://prod-registry-k8s-io-eu-central-1.s3.dualstack.eu-central-1.amazonaws.com",
      },
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
  // GCP europe-west8 is Milan, Italy
  europe-west8 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS eu-central-1 is Frankfurt
        value = "https://prod-registry-k8s-io-eu-central-1.s3.dualstack.eu-central-1.amazonaws.com",
      },
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
  // GCP europe-west9 is Paris, France
  europe-west9 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS eu-west-2 is London
        value = "https://prod-registry-k8s-io-eu-west-2.s3.dualstack.eu-west-2.amazonaws.com",
      },
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
  // GCP southamerica-west1 is Santiago, Chile
  southamerica-west1 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS us-east-1 is Virginia, USA
        // See: https://github.com/kubernetes/k8s.io/pull/4739/files#r1100667255
        value = "https://prod-registry-k8s-io-us-east-1.s3.dualstack.us-east-1.amazonaws.com",
      },
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
  // GCP us-central1 is Iowa, USA
  us-central1 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS us-east-2 is Ohio, USA
        value = "https://prod-registry-k8s-io-us-east-2.s3.dualstack.us-east-2.amazonaws.com",
      },
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
  // GCP us-east1 is South Carolina, USA
  us-east1 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS us-east-1 is Virginia, USA
        value = "https://prod-registry-k8s-io-us-east-1.s3.dualstack.us-east-1.amazonaws.com",
      },
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
  // GCP us-east4 is Virginia, USA
  us-east4 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS us-east-1 is Virginia, USA
        value = "https://prod-registry-k8s-io-us-east-1.s3.dualstack.us-east-1.amazonaws.com",
      },
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
  // GCP us-east5 is Ohio, USA
  us-east5 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS us-east-2 is Ohio, USA
        value = "https://prod-registry-k8s-io-us-east-2.s3.dualstack.us-east-2.amazonaws.com",
      },
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
  // GCP us-south1 is Texas, USA
  us-south1 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS us-east-2 is Ohio, USA
        value = "https://prod-registry-k8s-io-us-east-2.s3.dualstack.us-east-2.amazonaws.com",
      },
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
  // GCP us-west1 is Oregon, USA
  us-west1 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS us-west-2 is Oregon, USA
        value = "https://prod-registry-k8s-io-us-west-2.s3.dualstack.us-west-2.amazonaws.com",
      },
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
  // GCP us-west2 is California, USA
  us-west2 = {
    environment_variables = [
      {
        name = "DEFAULT_AWS_BASE_URL",
        // AWS us-west-1 is California, USA
        value = "https://prod-registry-k8s-io-us-west-1.s3.dualstack.us-west-1.amazonaws.com",
      },
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
