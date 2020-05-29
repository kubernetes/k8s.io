/*
Copyright 2019 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
	"testing"
	"unicode/utf8"
)

var cfg GroupsConfig

var groupsConfigPath = flag.String("groups-config", "./groups.yaml", "Path to groups config")

func TestMain(m *testing.M) {
	flag.Parse()
	if *groupsConfigPath == "" {
		fmt.Println("--groups-config must be set")
		os.Exit(1)
	}
	if err := readGroupsConfig(".", *groupsConfigPath, &cfg); err != nil {
		fmt.Printf("Could not load groups-config: %v", err)
		os.Exit(1)
	}
	os.Exit(m.Run())
}

// TestStagingEmailLength tests that the number of characters in the
// project name in emails used for staging repos does not exceed 18.
//
// This validation is needed because gcloud allows PROJECT_IDs of length
// between 6 and 30. So after discounting the "k8s-staging" prefix,
// we are left with 18 chars for the project name.
func TestStagingEmailLength(t *testing.T) {
	var errs []error
	for _, g := range cfg.Groups {
		if strings.HasPrefix(g.EmailId, "k8s-infra-staging-") {
			projectName := strings.TrimSuffix(strings.TrimPrefix(g.EmailId, "k8s-infra-staging-"), "@kubernetes.io")

			len := utf8.RuneCountInString(projectName)
			if len > 18 {
				errs = append(errs, fmt.Errorf("Number of characters in project name \"%s\" should not exceed 18; is: %d", projectName, len))
			}
		}
	}

	if errs != nil {
		for _, err := range errs {
			t.Error(err)
		}
	}
}

func TestK8sInfraGroupConventions(t *testing.T) {
	for _, g := range cfg.Groups {
		// TODO: expand from k8s-infra-staging-* to k8s-infra-*
		if strings.HasPrefix(g.EmailId, "k8s-infra-staging") {

			expectedEmailId := g.Name + "@kubernetes.io"
			if g.EmailId != expectedEmailId {
				t.Errorf("group '%s': expected email '%s', got '%s'", g.Name, expectedEmailId, g.EmailId)
			}

			if len(g.Owners) > 0 {
				t.Errorf("group '%s': must have no owners, only members", g.Name)
			}

		}
		if strings.HasPrefix(g.EmailId, "k8s-infra") {

			reconcileMembers, ok := g.Settings["ReconcileMembers"]
			if !ok || reconcileMembers != "true" {
				t.Errorf("group '%s': must have settings.ReconcileMembers = true", g.Name)
			}

		}
	}
}
