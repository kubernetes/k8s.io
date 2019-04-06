package main

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"

	compute "google.golang.org/api/compute/v1"
	"google.golang.org/api/googleapi"
	servicemanagement "google.golang.org/api/servicemanagement/v1"
	"k8s.io/klog"
)

type Cloud struct {
	Compute           *compute.Service
	ServiceManagement *servicemanagement.APIService
	Project           string
}

func getDefaultProject() (string, error) {
	name := "gcloud"
	args := []string{"config", "get-value", "project"}

	s := name + " " + strings.Join(args, " ")

	var stdout bytes.Buffer
	var stderr bytes.Buffer

	cmd := exec.Command(name, args...)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		klog.Warningf("error running %q; stdout=%q; stderr=%q", s, stdout.String(), stderr.String())
		return "", fmt.Errorf("error running %q: %v", s, err)
	}

	project := stdout.String()
	project = strings.TrimSpace(project)
	if project == "" {
		return "", fmt.Errorf("no default project set in gcloud: %v", err)
	}

	return project, nil
}

func NewCloud(ctx context.Context) (*Cloud, error) {
	project, err := getDefaultProject()
	if err != nil {
		return nil, fmt.Errorf("error getting default project: %v", err)
	}

	cloud := &Cloud{
		Project: project,
	}

	cloud.Compute, err = compute.NewService(ctx)
	if err != nil {
		return nil, fmt.Errorf("error creating compute service: %v", err)
	}

	cloud.ServiceManagement, err = servicemanagement.NewService(ctx)
	if err != nil {
		return nil, fmt.Errorf("error creating servicemanagement service: %v", err)
	}

	return cloud, nil
}

func (c *Cloud) WaitForServiceManagementOperation(op *servicemanagement.Operation) error {
	for {
		resp, err := c.ServiceManagement.Operations.Get(op.Name).Do()
		if err != nil {
			return fmt.Errorf("error getting status of operation: %v", err)
		}
		if resp.Done {
			return nil
		}
		klog.Warningf("waiting for servicemanagement operation %s", op.Name)
		time.Sleep(1 * time.Second)
	}
}

func (c *Cloud) WaitForComputeOperation(op *compute.Operation) error {
	for {
		var resp *compute.Operation
		var err error

		if op.Zone != "" {
			resp, err = c.Compute.ZoneOperations.Get(c.Project, op.Zone, op.Name).Do()
		} else if op.Region != "" {
			resp, err = c.Compute.RegionOperations.Get(c.Project, op.Region, op.Name).Do()
		} else {
			resp, err = c.Compute.GlobalOperations.Get(c.Project, op.Name).Do()
		}
		if err != nil {
			return fmt.Errorf("error getting status of operation: %v", err)
		}
		if resp.Status == "DONE" {
			return nil
		}
		klog.Warningf("waiting for compute operation %s", op.Name)
		time.Sleep(1 * time.Second)
	}
}

func IsNotFound(err error) bool {
	apiErr, ok := err.(*googleapi.Error)
	if !ok {
		return false
	}

	return apiErr.Code == 404
}
