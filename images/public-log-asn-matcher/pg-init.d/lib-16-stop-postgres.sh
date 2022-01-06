#!/bin/bash
# Copyright 2021 The Kubernetes Authors.
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

# Purpose: Stop Postgres

[ ! "${ASN_DATA_PIPELINE_RETAIN:-}" = true ] && \
# With a regular Postgres container, once the init.d scripts have completed
# Postgres stays alive. But for this image, since it's a job, it must exit after
# all processing has been completed.
# 
# To discover when the init.d scripts have completed
# the command of Postgres changes from "bash /usr/local/bin/docker-entrypoint.sh postgres" to "postgres" once it's completed loading up
# and is in a ready state and all of the init scripts have run
#
# here we wait for that state and attempt to exit cleanly, without error
(
  # discover where the postgres process is, even if Prow has injected a PID 1 process
  PARENTPID=$(ps -o ppid= -p $$ | awk '{print $1}')
  PID_FOR_POSTGRES=$$
  if [ ! "$(cat /proc/"${PARENTPID}"/cmdline)" = "/tools/entrypoint" ] && [ ! "${PARENTPID}" -eq 0 ]; then
      PID_FOR_POSTGRES=${PARENTPID}
  fi
  echo "Waiting for Postgres to have completed init"
  until [ "$(< /proc/"${PID_FOR_POSTGRES}"/cmdline tr '\0' '\n' | head -n 1)" = "postgres" ]; do
      sleep 1s
  done
  echo "Postgres has completed init"
  # exit Postgres with a code of 0
  pg_ctl kill QUIT "${PID_FOR_POSTGRES}"
) &
