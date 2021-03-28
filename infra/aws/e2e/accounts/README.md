# Management of AWS accounts

AWS accounts (and other cloud test accounts) are held in boskos ResourceObjects records.

The CRD itself is defined [here](https://raw.githubusercontent.com/kubernetes-sigs/boskos/master/deployments/base/crd.yaml).


## Administrative tasks

### List all boskos AWS accounts

```
kubectl get -resources.boskos.k8s.io -l cloud-provider=aws -A
```

### Audit all accounts in the org

Run the `audit.sh` script.


### Creating new AWS test account

Run the create-account script, passing in the number of the account to create.  Each account is named after today's date, followed by that number.

For example: `create-account.sh 01`


### Removing old AWS test accounts

TODO

After creating new keys, we should be able to remove the old keys from boskos, and then delete those AWS accounts.