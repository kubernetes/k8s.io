/*
Copyright 2024 The Kubernetes Authors.

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

resource "aws_iam_group" "maintainers" {
  name = "maintainers"
}

resource "aws_iam_group_membership" "maintainers" {
  name = "capa-maintainers"

  users = [
    aws_iam_user.ankitasw.name,
    aws_iam_user.dlipovetsky.name,
    aws_iam_user.richardcase.name,
    aws_iam_user.vincepri.name,
  ]

  group = aws_iam_group.maintainers.name
}

resource "aws_iam_group_policy_attachment" "maintainer-admin" {
  group      = aws_iam_group.maintainers.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
