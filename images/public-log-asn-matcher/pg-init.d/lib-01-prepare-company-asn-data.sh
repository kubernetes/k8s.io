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

# Purpose: download, prepare, and parse public ASN data
set -euo pipefail

curl -o /tmp/autnums.html -L https://bgp.potaroo.net/cidr/autnums.html
python3 /app/asn-autnums-extractor.py /tmp/autnums.html /tmp/potaroo_data.csv

# Strip data to only return ASN numbers
< /tmp/potaroo_data.csv cut -d ',' -f1 \
    | sed 's/"//' | sed 's/"//' \
    | sed '/^$/d' | cut -d 'S' -f2 \
    | sort | uniq \
    > /tmp/potaroo_asn.txt

# remove the '^AS' from each line
< /tmp/potaroo_data.csv tail -n +2 | sed 's,^AS,,g' > /tmp/potaroo_asn_companyname.csv

cd /tmp
if [ ! -f "rib.latest.bz2" ]; then
    pyasn_util_download.py --latest
    mv rib.*.*.bz2 rib.latest.bz2
fi
## Convert rib file to .dat we can process
if [ ! -f "ipasn_latest.dat" ]; then
    pyasn_util_convert.py --single rib.latest.bz2 ipasn_latest.dat
fi
## Run the py script we are including in the docker image
python3 /app/ip-from-pyasn.py /tmp/potaroo_asn.txt ipasn_latest.dat /tmp/pyAsnOutput.csv
## This will output pyasnOutput.csv
