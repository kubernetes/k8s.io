#!/bin/bash

# Copyright 2025 The Kubernetes Authors.
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

GCVE_PROW_CI_USERNAME="prow-ci-user"
GCVE_PROW_CI_GROUP="prow-ci-group"

# create user if it does not not exist
govc sso.user.ls | grep -q -e "${GCVE_PROW_CI_USERNAME}" || (govc sso.user.create -p "${GCVE_PROW_CI_PASSWORD}" "${GCVE_PROW_CI_USERNAME}" && echo "User ${GCVE_PROW_CI_USERNAME} created - Ensure to reset the correct password")

# create groups
govc sso.group.ls -search "${GCVE_PROW_CI_GROUP}" || (govc sso.group.create "${GCVE_PROW_CI_GROUP}" && echo "Group ${GCVE_PROW_CI_GROUP} created")

# add user to the group
govc sso.user.ls -group "${GCVE_PROW_CI_GROUP}" | grep -q "${GCVE_PROW_CI_USERNAME}" || (govc sso.group.update -a "${GCVE_PROW_CI_USERNAME}" "${GCVE_PROW_CI_GROUP}" && echo "Added user ${GCVE_PROW_CI_USERNAME} to group ${GCVE_PROW_CI_GROUP}")
