## Creating test accounts for e2e

* Edit the date in the scripts (bulk-create, attach and to-yaml)

* Create accounts with bulk-create.sh

* Attach roles to them with attach.sh

* Convert them to yaml with to-yaml.sh

* Make one nice yaml file with `cat *.yaml > secrets.txt`

* Ask the oss oncall to do something like `kubectl --context=k8s-prow-builds replace -f secrets.txt `

* After a while, delete the old AWS acouunts (though the console, I believe)
