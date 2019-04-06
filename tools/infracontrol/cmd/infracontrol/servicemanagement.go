package main

import (
	"context"
	"fmt"

	servicemanagement "google.golang.org/api/servicemanagement/v1"
	"k8s.io/klog"
)

type ManagedService struct {
	ServiceName string `json:"name,omitempty"`
	Enabled     *bool  `json:"enabled"`
}

type ReconcileManagedServiceOp struct {
	Cloud         *Cloud
	Expected      *ManagedService
	actual        *servicemanagement.ManagedService
	actualEnabled bool
}

func (op *ReconcileManagedServiceOp) Find(ctx context.Context) error {
	c := op.Cloud
	spec := op.Expected

	klog.Infof("listing services in project %q", c.Project)
	err := c.ServiceManagement.Services.List().ConsumerId("project:"+c.Project).Pages(ctx, func(page *servicemanagement.ListServicesResponse) error {
		for _, service := range page.Services {
			if service.ServiceName == spec.ServiceName {
				if op.actual != nil {
					return fmt.Errorf("found two servics with name %q", spec.ServiceName)
				}
				op.actual = service
			}
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("error enabling service %q: %v", spec.ServiceName, err)
	}

	// Only enabled services are returned
	op.actualEnabled = (op.actual != nil)

	return nil
}

func (op *ReconcileManagedServiceOp) Reconcile(ctx context.Context) error {
	c := op.Cloud
	spec := op.Expected

	if spec.Enabled != nil {
		if *spec.Enabled {
			if op.actualEnabled {
				klog.Infof("service %q is enabled", spec.ServiceName)
			} else {
				klog.Infof("enabling service %q", spec.ServiceName)
				request := &servicemanagement.EnableServiceRequest{
					ConsumerId: "project:" + c.Project,
				}
				o, err := c.ServiceManagement.Services.Enable(spec.ServiceName, request).Do()
				if err != nil {
					return fmt.Errorf("error enabling service %q: %v", spec.ServiceName, err)
				}
				if err := c.WaitForServiceManagementOperation(o); err != nil {
					return fmt.Errorf("error enabling service %q: %v", spec.ServiceName, err)
				}
			}
		}

		if !*spec.Enabled {
			if !op.actualEnabled {
				klog.Infof("service %q is disabled", spec.ServiceName)
			} else {
				klog.Infof("disabling service %q", spec.ServiceName)
				request := &servicemanagement.DisableServiceRequest{
					ConsumerId: "project:" + c.Project,
				}
				o, err := c.ServiceManagement.Services.Disable(spec.ServiceName, request).Do()
				if err != nil {
					return fmt.Errorf("error disabling service %q: %v", spec.ServiceName, err)
				}
				if err := c.WaitForServiceManagementOperation(o); err != nil {
					return fmt.Errorf("error disabling service %q: %v", spec.ServiceName, err)
				}
			}
		}
	}

	return nil
}
