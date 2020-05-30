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
	"reflect"
	"sort"
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

// Enforce conventions for all groups
func TestGroupConventions(t *testing.T) {
	for _, g := range cfg.Groups {
		// groups are easier to reason about if email and name match
		expectedEmailId := g.Name + "@kubernetes.io"
		if g.EmailId != expectedEmailId {
			t.Errorf("group '%s': expected email '%s', got '%s'", g.Name, expectedEmailId, g.EmailId)
		}
	}
}

// Enforce conventions for all k8s-infra groups
func TestK8sInfraGroupConventions(t *testing.T) {
	for _, g := range cfg.Groups {
		if strings.HasPrefix(g.EmailId, "k8s-infra") {
			// no owners because we want to prevent manual membership changes
			if len(g.Owners) > 0 {
				t.Errorf("group '%s': must have no owners, only members", g.Name)
			}

			// treat files here as source of truth for membership
			reconcileMembers, ok := g.Settings["ReconcileMembers"]
			if !ok || reconcileMembers != "true" {
				t.Errorf("group '%s': must have settings.ReconcileMembers = true", g.Name)
			}
		}
	}
}

// Enforce conventions for groups used by GKE Group-based RBAC
// - there must be a gke-security-groups@ group
// - its members must be k8s-infra-rbac-*@ groups (and vice-versa)
// - all groups involved must have settings.WhoCanViewMembership = ALL_MEMBERS_CAN_VIEW
func TestK8sInfraRBACGroupConventions(t *testing.T) {
	rbacEmails := make(map[string]bool)
	for _, g := range cfg.Groups {
		if strings.HasPrefix(g.EmailId, "k8s-infra-rbac") {
			rbacEmails[g.EmailId] = false
			// this is necessary for group-based rbac to work
			whoCanViewMembership, ok := g.Settings["WhoCanViewMembership"]
			if !ok || whoCanViewMembership != "ALL_MEMBERS_CAN_VIEW" {
				t.Errorf("group '%s': must have settings.WhoCanViewMembership = ALL_MEMBERS_CAN_VIEW", g.Name)
			}
		}
	}
	foundGKEGroup := false
	for _, g := range cfg.Groups {
		if g.EmailId == "gke-security-groups@kubernetes.io" {
			foundGKEGroup = true
			// this is necessary for group-based rbac to work
			whoCanViewMembership, ok := g.Settings["WhoCanViewMembership"]
			if !ok || whoCanViewMembership != "ALL_MEMBERS_CAN_VIEW" {
				t.Errorf("group '%s': must have settings.WhoCanViewMembership = ALL_MEMBERS_CAN_VIEW", g.Name)
			}
			for _, email := range g.Members {
				if _, ok := rbacEmails[email]; !ok {
					t.Errorf("group '%s': invalid member '%s', must be a k8s-infra-rbac-*@kubernetes.io group", g.Name, email)
				} else {
					rbacEmails[email] = true
				}
			}
		}
	}
	if !foundGKEGroup {
		t.Errorf("group '%s' is missing", "gke-security-groups@kubernetes.io")
	}
	for email, found := range rbacEmails {
		if !found {
			t.Errorf("group '%s': must be a member of gke-security-groups@kubernetes.io", email)
		}
	}
}

// NOTE: make very certain you know what you are doing if you change one
// of these groups, we don't want to accidentally lock ourselves out
func TestHardcodedGroupsForParanoia(t *testing.T) {
	groups := map[string][]string{
		"k8s-infra-gcp-org-admins@kubernetes.io": []string{
			"cblecker@gmail.com",
			"davanum@gmail.com",
			"ihor@cncf.io",
			"spiffxp@google.com",
			"thockin@google.com",
		},
		"k8s-infra-group-admins@kubernetes.io": []string{
			"cblecker@gmail.com",
			"davanum@gmail.com",
			"spiffxp@google.com",
			"thockin@google.com",
		},
	}

	found := make(map[string]bool)

	for _, g := range cfg.Groups {
		if expected, ok := groups[g.EmailId]; ok {
			found[g.EmailId] = true
			sort.Strings(expected)
			actual := make([]string, len(g.Members))
			copy(actual, g.Members)
			sort.Strings(actual)
			if !reflect.DeepEqual(expected, actual) {
				t.Errorf("group '%s': expected members '%v', got '%v'", g.Name, expected, actual)
			}
		}
	}

	for email, _ := range groups {
		if _, ok := found[email]; !ok {
			t.Errorf("group '%s' is missing, should be present", email)
		}
	}
}
