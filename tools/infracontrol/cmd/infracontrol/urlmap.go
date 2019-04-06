package main

import (
	"context"
	"fmt"

	compute "google.golang.org/api/compute/v1"
	"k8s.io/klog"
)

type URLMap struct {
	Name           string `json:"name,omitempty"`
	DefaultService string `json:"defaultService,omitempty"`
}

type ReconcileURLMapOp struct {
	Cloud    *Cloud
	Expected *URLMap
	Actual   *compute.UrlMap
}

func (op *ReconcileURLMapOp) Find(ctx context.Context) error {
	c := op.Cloud
	spec := op.Expected

	klog.Infof("looking for GCLB URLMap %q", spec.Name)

	urlMap, err := c.Compute.UrlMaps.Get(c.Project, spec.Name).Do()
	if err != nil {
		if !IsNotFound(err) {
			return fmt.Errorf("error getting urlMap: %v", err)
		}
	} else {
		op.Actual = urlMap
	}
	return nil
}

func (op *ReconcileURLMapOp) Reconcile(ctx context.Context) error {
	c := op.Cloud
	spec := op.Expected
	actual := op.Actual

	if actual == nil {
		klog.Infof("creating GCLB URLMap %q", spec.Name)

		request := &compute.UrlMap{
			Name:           spec.Name,
			DefaultService: spec.DefaultService,
		}

		o, err := c.Compute.UrlMaps.Insert(c.Project, request).Do()
		if err != nil {
			return fmt.Errorf("error creating urlMap: %v", err)
		}
		if err := c.WaitForComputeOperation(o); err != nil {
			return fmt.Errorf("error creating urlMap: %v", err)
		}

		return nil
	}

	if spec.DefaultService != actual.DefaultService {
		// TODO: Normalize URLs then make an error
		//return fmt.Errorf("changing DefaultService not implemented: %q vs %q", spec.DefaultService, actual.DefaultService)
		klog.Warningf("changing DefaultService not implemented: %q vs %q", spec.DefaultService, actual.DefaultService)
	}

	return nil
}
