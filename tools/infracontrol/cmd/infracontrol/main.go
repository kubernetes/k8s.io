package main

import (
	"context"
	"fmt"
	"os"
)

func main() {
	ctx := context.Background()
	err := run(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	} else {
		os.Exit(0)
	}
}

func run(ctx context.Context) error {
	cloud, err := NewCloud(ctx)
	if err != nil {
		return fmt.Errorf("error initializing cloud api: %v", err)
	}

	bucket := "justinsb-k8s-staging-kops"
	key := "prod-artifacts"
	address := "35.244.254.113"

	var tasks []Task

	msEnabled := true
	ms := &ManagedService{
		ServiceName: "compute.googleapis.com",
		Enabled:     &msEnabled,
	}

	tasks = append(tasks, &ReconcileManagedServiceOp{
		Cloud:    cloud,
		Expected: ms,
	})

	bb := &BackendBucket{
		Name:       bucket,
		BucketName: bucket,
	}
	tasks = append(tasks, &ReconcileBackendBucketOp{
		Cloud:    cloud,
		Expected: bb,
	})

	um := &URLMap{
		Name:           key,
		DefaultService: "global/backendBuckets/" + bb.Name,
	}
	tasks = append(tasks, &ReconcileURLMapOp{
		Cloud:    cloud,
		Expected: um,
	})

	thp := &TargetHTTPProxy{
		Name:   key,
		URLMap: "global/urlMaps/" + um.Name,
	}
	tasks = append(tasks, &ReconcileTargetHTTPProxyOp{
		Cloud:    cloud,
		Expected: thp,
	})

	fr := &ForwardingRule{
		Name:      key,
		Target:    "global/targetHttpProxies/" + thp.Name,
		PortRange: "80",
		IPAddress: address,
	}
	tasks = append(tasks, &ReconcileForwardingRuleOp{
		Cloud:    cloud,
		Expected: fr,
	})

	for _, task := range tasks {
		if err := task.Find(ctx); err != nil {
			return fmt.Errorf("error finding %T: %v", task, err)
		}

		if err := task.Reconcile(ctx); err != nil {
			return fmt.Errorf("error reconciling %T: %v", task, err)
		}
	}

	return nil
}

type Task interface {
	Find(ctx context.Context) error
	Reconcile(ctx context.Context) error
}
