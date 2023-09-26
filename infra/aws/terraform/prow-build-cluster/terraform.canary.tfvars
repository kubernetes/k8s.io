/*
Copyright 2023 The Kubernetes Authors.

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

aws_account_id = "054318140392"

eks_cluster_viewers = [
  "pkprzekwas",
  "wozniakjan",
  "xmudrii"
]

eks_cluster_admins = [
  "pkprzekwas",
  "wozniakjan",
  "xmudrii"
]

cluster_name               = "prow-canary-cluster"
cluster_version            = "1.25"
cluster_autoscaler_version = "v1.25.0"

# Ubuntu EKS optimized AMI: https://cloud-images.ubuntu.com/aws-eks/
node_ami_blue            = "ami-05da66fc7a4319aa8"
node_instance_types_blue = ["r5d.xlarge"]

node_min_size_blue     = 3
node_max_size_blue     = 3
node_desired_size_blue = 3

node_ami_green            = "ami-05da66fc7a4319aa8"
node_instance_types_green = ["r5d.xlarge"]

node_min_size_green     = 0
node_max_size_green     = 1
node_desired_size_green = 0

node_taints_green = []

node_labels_green = {}

node_volume_size = 100

node_max_unavailable_percentage = 100 # To ease testing

public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFJvXxqAJV+C84330Qp1Zx0Uq3TWbalOKlStfii2vnU9STalSOZ2oa4y2nG5Pu4Ah2G7ZSCVuaReagt2ESUNGdttT06llK8JjFce3n6nc7N6imPwR/e+csf0TV4ckLVugIJpHPgLBujpvml7c1SdlZZXKul6ZX0R6Z96JFpSrYOPyrTVl2yCqKqMEVEwOvvOxlO3vMTTyK/Z1d5jOyHFQ/88DdxWWeyugps4+++WtgcRvHe7vwcsOZYJWGL639jOcNpuXjyLXLL9CAGuDwFzDxomzSBcTaPmYtS3kJQPQOdmt2S0FoO/vHBEnvbGrEjlyzWluBLNPvn1rclCJghiv+ndF4AYSe/7FlWCEiZaDNJghF6PMyAPxIar9sAurFia9FMur4zy93ZA8iJeUKlzhImv/u1f2XjPef/Iu8Ni+eIVDYGVXZzWM7Qrw30mhLZhfrob8ZQ6MPQjMdQ+LZ3TAxZwk2QWG8qAMmUXvbbtS7aPGZL2R6+ZZ/Z3WA3T+pGUde9SRvhGlN1/Up85NGOGDAJICXKICTFJNEfp6yK65wAVC5URuoLw3Zacji+uodefWQovF3ke8rHLghqTR1l3jkWDddyejvt5Rf1mdV7xL0stRcoiXfM4MTSuQ3qbpBIsgCGzjjrseq5z3e85DgcXzdfuerDk0y0peH0pXAQCp8oQ=="
