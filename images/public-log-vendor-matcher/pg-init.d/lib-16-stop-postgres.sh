#!/bin/bash
# Purpose: Stop Postgres

[ ! "${ASN_DATA_PIPELINE_RETAIN:-}" = true ] && \
# in the Postgres container image,
# the command run changes to "postgres" once it's completed loading up
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
  until [ "$(< /proc/"${PID}"/cmdline tr '\0' '\n' | head -n 1)" = "postgres" ]; do
      sleep 1s
  done
  # exit Postgres with a code of 0
  pg_ctl kill QUIT "${PID_FOR_POSTGRES}"
) &
