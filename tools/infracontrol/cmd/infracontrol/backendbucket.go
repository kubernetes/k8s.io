package main

import (
	"context"
	"fmt"

	compute "google.golang.org/api/compute/v1"
	"k8s.io/klog"
)

type BackendBucket struct {
	Name       string `json:"name,omitempty"`
	BucketName string `json:"bucketName,omitempty"`
}

type ReconcileBackendBucketOp struct {
	Cloud    *Cloud
	Expected *BackendBucket
	Actual   *compute.BackendBucket
}

func (op *ReconcileBackendBucketOp) Find(ctx context.Context) error {
	c := op.Cloud
	spec := op.Expected

	klog.Infof("looking for GCLB BackendBucket %q", spec.Name)

	backendBucket, err := c.Compute.BackendBuckets.Get(c.Project, spec.Name).Do()
	if err != nil {
		if !IsNotFound(err) {
			return fmt.Errorf("error getting backendBucket: %v", err)
		}
	} else {
		op.Actual = backendBucket
	}
	return nil
}

func (op *ReconcileBackendBucketOp) Reconcile(ctx context.Context) error {
	c := op.Cloud
	spec := op.Expected
	actual := op.Actual

	if actual == nil {
		klog.Infof("creating GCLB BackendBucket %q", spec.Name)

		request := &compute.BackendBucket{
			Name:       spec.Name,
			BucketName: spec.BucketName,
		}

		o, err := c.Compute.BackendBuckets.Insert(c.Project, request).Do()
		if err != nil {
			return fmt.Errorf("error creating backendBucket: %v", err)
		}
		if err := c.WaitForComputeOperation(o); err != nil {
			return fmt.Errorf("error creating backendBucket: %v", err)
		}

		return nil
	}

	if spec.BucketName != actual.BucketName {
		return fmt.Errorf("changing BucketName not implemented")
	}

	return nil
}
