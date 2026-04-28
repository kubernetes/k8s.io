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

## Import pyasn and csv
import pyasn
import csv
import sys

## Set file path
asnFile = sys.argv[1]
asnDat = sys.argv[2]
pyAsnOutput = sys.argv[3]
## Open asnNumFile and read
asnNum = [line.rstrip() for line in open(asnFile, "r+")]

## assign our dat file connection string
asndb = pyasn.pyasn(asnDat)
## Declare empty dictionary
destDict = {}
singleAsn = ""

missingSubnets = []
## Loop through list of asns
for singleAsn in asnNum:
    ## Go look up the asn subnets (prefixes)
    subnets = asndb.get_as_prefixes(singleAsn)
    ## Add checking to make sure we have subnets
    ## TODO: insert asn with no routes so we know which failed without having to do a lookup
    if subnets:
        ## Add subnets to our dictionaries with
        originAsnDict = {sbnets : singleAsn for sbnets in subnets}
        ## This is what lets us append each loop to the final destDict
        destDict.update(originAsnDict)

if len(missingSubnets) > 0:
    print("Subnets missing from ASNs: ", missingSubnets)

## Open handle to output file
resultsCsv = open(pyAsnOutput, "w")
# write to csv
writer = csv.writer(resultsCsv)
for key, value in destDict.items():
    writer.writerow([key, value])
