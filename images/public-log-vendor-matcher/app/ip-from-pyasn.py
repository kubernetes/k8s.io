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
    ## TODO: insert asn with no routes so we know which faiGCP_BIGQUERY_DATASETled without having to do a lookup
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
