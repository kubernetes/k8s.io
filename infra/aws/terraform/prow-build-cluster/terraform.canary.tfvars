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
node_ami_blue            = "ami-07e8e7dddc8b3bad9"
node_instance_types_blue = ["r5d.xlarge"]

node_min_size_blue     = 0
node_max_size_blue     = 3
node_desired_size_blue = 0

node_ami_green            = "ami-07e8e7dddc8b3bad9"
node_instance_types_green = ["r5d.xlarge"]

node_min_size_green     = 1
node_max_size_green     = 3
node_desired_size_green = 1

node_volume_size = 100

node_max_unavailable_percentage = 100 # To ease testing

public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDTy+Rad9AtfTxTfmeNN6yvWSOwg3ytaJCWLwdOG/XAADJx5pRVIJ/OrYy/nO0sCMrjXf+Pv+JlERJA9pZIKahkiUNMG537Ubw9OjVhgtlhfO/PQNWa3aESpRPHYp/QOCHqj5ni75f/TpxVVO70tys4h75Et++tGdjEXfoTf03Sjk10ShYRzxf6LyZ8RkG2yJqN4hETe+YXP3ohBsv0dgt7bybSgRgLEpz9TLIpBjM5ZUdb2QQ4Grs/l+wne/tH6lu4p4ltEGSCByqzIw3XR1OWU+NrHFY2elsef1CQAvtIXv8QfFOUAur4VyXop/NC69+qG0uJcFQtrqPH3mma/NtJ7vnxZw1oJy2B5U1QdLuxpXu2VVLz3y0dPQ1PDKJWY4RxfyzY835Rv73XzwugvgZVehrgJ6gHeBBiwTDalz+DJuwlkUpHhfSjkk0xDxJyJdg4uncZld6NiJaOU/Fv901VyLuXQ/gQGIWRSm7ynTZda4uAfhhPbXab46+1yN6KERzo0sTQDnI2+dG/zZqIi9rwKsBG1mPvg8T1I78aN1w3ooPluYhFhMMfdUMHHzoItaXh+87Y1yPy0nrQZMk4oOK7g4+VXaN7PyqTLExecgTAHufnX9iEjsmBr2LT8nXMUvHjvrWeMJV0bgnTNc4qo3pOf+eatZVun+vSmDmFp4fYgw== kubernetes-sig-k8s-infra"
