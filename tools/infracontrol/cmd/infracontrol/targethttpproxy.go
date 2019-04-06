package main

import (
	"context"
	"fmt"

	compute "google.golang.org/api/compute/v1"
	"k8s.io/klog"
)

type TargetHTTPProxy struct {
	Name   string `json:"name,omitempty"`
	URLMap string `json:"urlMap,omitempty"`
}

type ReconcileTargetHTTPProxyOp struct {
	Cloud    *Cloud
	Expected *TargetHTTPProxy
	Actual   *compute.TargetHttpProxy
}

func (op *ReconcileTargetHTTPProxyOp) Find(ctx context.Context) error {
	c := op.Cloud
	spec := op.Expected

	klog.Infof("looking for GCLB TargetHTTPProxy %q", spec.Name)

	urlMap, err := c.Compute.TargetHttpProxies.Get(c.Project, spec.Name).Do()
	if err != nil {
		if !IsNotFound(err) {
			return fmt.Errorf("error getting urlMap: %v", err)
		}
	} else {
		op.Actual = urlMap
	}
	return nil
}

func (op *ReconcileTargetHTTPProxyOp) Reconcile(ctx context.Context) error {
	c := op.Cloud
	spec := op.Expected
	actual := op.Actual

	if actual == nil {
		klog.Infof("creating GCLB TargetHTTPProxy %q", spec.Name)

		request := &compute.TargetHttpProxy{
			Name:   spec.Name,
			UrlMap: spec.URLMap,
		}

		o, err := c.Compute.TargetHttpProxies.Insert(c.Project, request).Do()
		if err != nil {
			return fmt.Errorf("error creating urlMap: %v", err)
		}
		if err := c.WaitForComputeOperation(o); err != nil {
			return fmt.Errorf("error creating urlMap: %v", err)
		}

		return nil
	}

	if spec.URLMap != actual.UrlMap {
		// TODO: Normalize URLs then make an error
		//return fmt.Errorf("changing URLMap not implemented: %q vs %q", spec.URLMap, actual.UrlMap)
		klog.Warningf("changing URLMap not implemented: %q vs %q", spec.URLMap, actual.UrlMap)
	}

	return nil
}
