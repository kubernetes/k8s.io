package main

import (
	"context"
	"fmt"

	compute "google.golang.org/api/compute/v1"
	"k8s.io/klog"
)

type ForwardingRule struct {
	Name      string `json:"name,omitempty"`
	Target    string `json:"target,omitempty"`
	PortRange string `json:"portRange,omitempty"`
	IPAddress string `json:"ipAddress,omitempty"`
}

type ReconcileForwardingRuleOp struct {
	Cloud    *Cloud
	Expected *ForwardingRule
	Actual   *compute.ForwardingRule
}

func (op *ReconcileForwardingRuleOp) Find(ctx context.Context) error {
	c := op.Cloud
	spec := op.Expected

	klog.Infof("looking for GCLB ForwardingRule %q", spec.Name)

	forwardingRule, err := c.Compute.GlobalForwardingRules.Get(c.Project, spec.Name).Do()
	if err != nil {
		if !IsNotFound(err) {
			return fmt.Errorf("error getting forwardingRule: %v", err)
		}
	} else {
		op.Actual = forwardingRule
	}
	return nil
}

func (op *ReconcileForwardingRuleOp) Reconcile(ctx context.Context) error {
	c := op.Cloud
	spec := op.Expected
	actual := op.Actual

	if actual == nil {
		klog.Infof("creating GCLB ForwardingRule %q", spec.Name)

		request := &compute.ForwardingRule{
			Name:      spec.Name,
			Target:    spec.Target,
			PortRange: spec.PortRange,
			IPAddress: spec.IPAddress,
		}

		o, err := c.Compute.GlobalForwardingRules.Insert(c.Project, request).Do()
		if err != nil {
			return fmt.Errorf("error creating forwardingRule: %v", err)
		}
		if err := c.WaitForComputeOperation(o); err != nil {
			return fmt.Errorf("error creating forwardingRule: %v", err)
		}

		return nil
	}

	if spec.Target != actual.Target {
		// TODO: Normalize URLs then make an error
		//return fmt.Errorf("changing Target not implemented: %q vs %q", spec.Target, actual.Target)
		klog.Warningf("changing Target not implemented: %q vs %q", spec.Target, actual.Target)
	}

	if spec.PortRange != actual.PortRange {
		return fmt.Errorf("changing PortRange not implemented: %q vs %q", spec.PortRange, actual.PortRange)
	}

	if spec.IPAddress != actual.IPAddress {
		return fmt.Errorf("changing IPAddress not implemented: %q vs %q", spec.IPAddress, actual.IPAddress)
	}

	return nil
}
