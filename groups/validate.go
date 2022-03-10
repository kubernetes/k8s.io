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
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
	"unicode/utf8"

	utilerrors "k8s.io/apimachinery/pkg/util/errors"
	"k8s.io/apimachinery/pkg/util/sets"
)

func Validate(configPath, restrictionsPath, groupsPath *string) error {
	var err error

	// Check if config.yaml is loadable
	if *configPath != "" && !filepath.IsAbs(*configPath) {
		return fmt.Errorf("config \"%s\" must be an absolute path\n", *configPath)
	}

	if *configPath == "" {
		baseDir, err := os.Getwd()
		if err != nil {
			return fmt.Errorf("cannot get current working directory: %v\n", err)
		}
		cPath := filepath.Join(baseDir, defaultConfigFile)
		configPath = &cPath
	}

	if err := config.Load(*configPath, false); err != nil {
		return fmt.Errorf("could not load main config: %v\n", err)
	}

	// Check if restrictions.yaml is loadable
	if *restrictionsPath != "" && !filepath.IsAbs(*restrictionsPath) {
		return fmt.Errorf("restrictions-path \"%s\" must be an absolute path\n", *restrictionsPath)
	}

	if *restrictionsPath == "" {
		baseDir, err := os.Getwd()
		if err != nil {
			return fmt.Errorf("cannot get current working directory: %v\n", err)
		}
		rPath := filepath.Join(baseDir, defaultRestrictionsFile)
		restrictionsPath = &rPath
	}

	if err := restrictionsConfig.Load(*restrictionsPath); err != nil {
		return fmt.Errorf("could not load restrictions config: %v\n", err)
		os.Exit(1)
	}

	// Print config to terminal
	PrintConfig(config)

	// Check if groups config can be loaded
	if *groupsPath != "" && !filepath.IsAbs(*groupsPath) {
		return fmt.Errorf("groups-path \"%s\" must be an absolute path\n", *groupsPath)
	}

	if *groupsPath == "" {
		*groupsPath, err = os.Getwd()
		if err != nil {
			return fmt.Errorf("cannot get current working directory: %v\n", err)
		}
	}

	if err := groupsConfig.Load(*groupsPath, &restrictionsConfig); err != nil {
		return fmt.Errorf("could not load groups config: %v\n", err)
	}

	// Run all the Verification Logic
	if err = VerifyStagingEmailLength(config, groupsConfig); err != nil {
		return err
	}

	if err = VerifyMergedGroupsConfig(config, groupsConfig); err != nil {
		return err
	}

	if err = VerifyDescriptionLength(groupsConfig); err != nil {
		return err
	}

	if err = VerifyGroupConventions(config, groupsConfig); err != nil {
		return err
	}

	if err = VerifyK8sInfraGroupConventions(groupsConfig); err != nil {
		return err
	}

	if err = VerifyK8sInfraRBACGroupConventions(groupsConfig); err != nil {
		return err
	}

	if config.SkipKubernetesIOTests {
		return nil
	}

	// The tests are K8s Specific tests
	if err = VerifySecurityResponseCommitteeGroups(groupsConfig); err != nil {
		return err
	}

	if err = VerifyNoDuplicateMembers(groupsConfig); err != nil {
		return err
	}
	if err = VerifyHardcodedGroupsForParanoia(groupsConfig); err != nil {
		return err
	}
	if err = VerifyGroupsWhichShouldSupportHistory(groupsConfig); err != nil {
		return err
	}

	return nil
}

// VerifyMergedGroupsConfig tests that readGroupsConfig reads all
// groups.yaml files and the merged config does not contain any duplicates.
//
// It tests that the config is merged by checking that the final
// GroupsConfig contains at least one group that isn't in the
// root groups.yaml file.
func VerifyMergedGroupsConfig(config Config, groupsConfig GroupsConfig) error {
	var containsMergedConfig bool
	found := sets.String{}
	dups := sets.String{}

	for _, g := range groupsConfig.Groups {
		name := g.Name

		if name == "security" {
			containsMergedConfig = true
		}

		if found.Has(name) {
			dups.Insert(name)
		}
		found.Insert(name)
	}

	if !containsMergedConfig {
		return fmt.Errorf("final GroupsConfig does not have merged configs from all groups.yaml files")
	}
	if n := len(dups); n > 0 {
		return fmt.Errorf("%d duplicate groups: %s", n, strings.Join(dups.List(), ", "))
	}

	return nil
}

// VerifyStagingEmailLength tests that the number of characters in the
// project name in emails used for staging repos does not exceed 18.
//
// This validation is needed because gcloud allows PROJECT_IDs of length
// between 6 and 30. So after discounting the "k8s-staging" prefix,
// we are left with 18 chars for the project name.
func VerifyStagingEmailLength(config Config, groupsConfig GroupsConfig) error {
	primaryDomain := config.Domains[0]
	var errs []error
	for _, g := range groupsConfig.Groups {
		if strings.HasPrefix(g.EmailId, "k8s-infra-staging-") {
			projectName := strings.TrimSuffix(strings.TrimPrefix(g.EmailId, "k8s-infra-staging-"), "@"+primaryDomain)

			len := utf8.RuneCountInString(projectName)
			if len > 18 {
				errs = append(errs, fmt.Errorf("number of characters in project name \"%s\" should not exceed 18; is: %d", projectName, len))
			}
		}
	}

	return utilerrors.NewAggregate(errs)
}

// VerifyDescriptionLength tests that the number of characters in the
// google groups description does not exceed 300.
//
// This validation is needed because gcloud allows apps:description
// with length no greater than 300
func VerifyDescriptionLength(groupsConfig GroupsConfig) error {
	var errs []error
	for _, g := range groupsConfig.Groups {
		description := g.Description

		len := utf8.RuneCountInString(description)
		//Ref: https://developers.google.com/admin-sdk/groups-settings/v1/reference/groups
		if len > 300 {
			errs = append(errs,
				fmt.Errorf("number of characters in description \"%s\" for group name \"%s\" "+
					"should not exceed 300; is: %d", description, g.Name, len))
		}
	}

	return utilerrors.NewAggregate(errs)
}

// Enforce conventions for all groups
func VerifyGroupConventions(config Config, groupsConfig GroupsConfig) error {
	// aggregate the errors that occured and return them together in the end.
	var errs []error

	primaryDomain := config.Domains[0]
	for _, g := range groupsConfig.Groups {
		// groups are easier to reason about if email and name match
		expectedEmailID := g.Name + "@" + primaryDomain
		if g.EmailId != expectedEmailID {
			errs = append(errs, fmt.Errorf("group '%s': expected email '%s', got '%s'\n", g.Name, expectedEmailID, g.EmailId))
		}
	}
	return utilerrors.NewAggregate(errs)
}

// Enforce conventions for all k8s-infra groups
func VerifyK8sInfraGroupConventions(groupsConfig GroupsConfig) error {
	// aggregate the errors that occured and return them together in the end.
	var errs []error

	for _, g := range groupsConfig.Groups {
		if strings.HasPrefix(g.EmailId, "k8s-infra") {
			// no owners because we want to prevent manual membership changes
			if len(g.Owners) > 0 {
				errs = append(errs, fmt.Errorf("group '%s': must have no owners, only members", g.Name))
			}

			// treat files here as source of truth for membership
			reconcileMembers, ok := g.Settings["ReconcileMembers"]
			if !ok || reconcileMembers != "true" {
				errs = append(errs, fmt.Errorf("group '%s': must have settings.ReconcileMembers = true", g.Name))
			}
		}
	}
	return utilerrors.NewAggregate(errs)
}

// Enforce conventions for groups used by GKE Group-based RBAC
// - there must be a gke-security-groups@ group
// - its members must be k8s-infra-rbac-*@ groups (and vice-versa)
// - all groups involved must have settings.WhoCanViewMembership = ALL_MEMBERS_CAN_VIEW
func VerifyK8sInfraRBACGroupConventions(groupsConfig GroupsConfig) error {
	// aggregate the errors that occured and return them together in the end.
	var errs []error

	primaryDomain := config.Domains[0]
	rbacEmails := make(map[string]bool)
	for _, g := range groupsConfig.Groups {
		if strings.HasPrefix(g.EmailId, "k8s-infra-rbac") {
			rbacEmails[g.EmailId] = false
			// this is necessary for group-based rbac to work
			whoCanViewMembership, ok := g.Settings["WhoCanViewMembership"]
			if !ok || whoCanViewMembership != "ALL_MEMBERS_CAN_VIEW" {
				errs = append(errs, fmt.Errorf("group '%s': must have settings.WhoCanViewMembership = ALL_MEMBERS_CAN_VIEW", g.Name))
			}
		}
	}
	foundGKEGroup := false
	for _, g := range groupsConfig.Groups {
		if g.EmailId == "gke-security-groups@"+primaryDomain {
			foundGKEGroup = true
			// this is necessary for group-based rbac to work
			whoCanViewMembership, ok := g.Settings["WhoCanViewMembership"]
			if !ok || whoCanViewMembership != "ALL_MEMBERS_CAN_VIEW" {
				errs = append(errs, fmt.Errorf("group '%s': must have settings.WhoCanViewMembership = ALL_MEMBERS_CAN_VIEW", g.Name))
			}
			for _, email := range g.Members {
				if _, ok := rbacEmails[email]; !ok {
					errs = append(errs, fmt.Errorf("group '%s': invalid member '%s', must be a k8s-infra-rbac-*@"+primaryDomain+"group", g.Name, email))
				} else {
					rbacEmails[email] = true
				}
			}
		}
	}
	if !foundGKEGroup {
		errs = append(errs, fmt.Errorf("group '%s' is missing", "gke-security-groups@"+primaryDomain))
	}
	for email, found := range rbacEmails {
		if !found {
			errs = append(errs, fmt.Errorf("group '%s': must be a member of gke-security-groups@"+primaryDomain, email))
		}
	}

	return utilerrors.NewAggregate(errs)
}

// Enforce conventions for SRC groups
// - groups can't own other groups, so for groups that should be owned by
//	 security@kubernetes.io should own, make sure the owners match

// TODO: It may not matter, but it would be more efficient to put the pscGroups
// into a set or map and scan groupsConfig.Groups only once (or 1.5 times, since
// we scan for security@kubernetes.io earlier.
// Separately, it feels like having groupsConfig.Groups be a map[string]GroupConfig
// would be a big win for some of these loops, especially if you could combine the
// "verification function" for several different verifications using something like
// the Visitor pattern.
// https://github.com/kubernetes/k8s.io/pull/3407#discussion_r808644893

func VerifySecurityResponseCommitteeGroups(groupsConfig GroupsConfig) error {
	// aggregate the errors that occured and return them together in the end.
	var errs []error

	pscGroups := []string{
		"distributors-announce@kubernetes.io",
		"security-discuss-private@kubernetes.io",
	}
	owners := []string{}
	for _, g := range groupsConfig.Groups {
		if g.EmailId == "security@kubernetes.io" {
			owners = g.Owners
			break
		}
	}
	for _, pscGroup := range pscGroups {
		for _, g := range groupsConfig.Groups {
			if g.EmailId == pscGroup {
				if !reflect.DeepEqual(owners, g.Owners) {
					errs = append(errs, fmt.Errorf("group '%s': owners must match owners from security@kubernetes.io, expected: %v, actual: %v", pscGroup, owners, g.Owners))
				}
				break
			}
		}
	}

	return utilerrors.NewAggregate(errs)
}

// An e-mail address can only show up once within a given group, whether that
// be as a member, manager, or owner
func VerifyNoDuplicateMembers(groupsConfig GroupsConfig) error {
	// aggregate the errors that occured and return them together in the end.
	var errs []error

	for _, g := range groupsConfig.Groups {
		members := map[string]bool{}
		for _, m := range g.Members {
			if _, ok := members[m]; ok {
				errs = append(errs, fmt.Errorf("group '%s' cannot have duplicate member '%s'", g.EmailId, m))
			}
			members[m] = true
		}
		managers := map[string]bool{}
		for _, m := range g.Managers {
			if _, ok := members[m]; ok {
				errs = append(errs, fmt.Errorf("group '%s' manager '%s' cannot also be listed as a member", g.EmailId, m))
			}
			if _, ok := managers[m]; ok {
				errs = append(errs, fmt.Errorf("group '%s' cannot have duplicate manager '%s'", g.EmailId, m))
			}
			managers[m] = true
		}
		owners := map[string]bool{}
		for _, m := range g.Owners {
			if _, ok := members[m]; ok {
				errs = append(errs, fmt.Errorf("group '%s' owner '%s' cannot also be listed as a member", g.EmailId, m))
			}
			if _, ok := managers[m]; ok {
				errs = append(errs, fmt.Errorf("group '%s' owner '%s' cannot also be listed as a manager", g.EmailId, m))
			}
			if _, ok := owners[m]; ok {
				errs = append(errs, fmt.Errorf("group '%s' cannot have duplicate owner '%s'", g.EmailId, m))
			}
			owners[m] = true
		}
	}

	return utilerrors.NewAggregate(errs)
}

// NOTE: make very certain you know what you are doing if you change one
// of these groups, we don't want to accidentally lock ourselves out
func VerifyHardcodedGroupsForParanoia(groupsConfig GroupsConfig) error {
	// aggregate the errors that occured and return them together in the end.
	var errs []error

	groups := map[string][]string{
		"k8s-infra-gcp-org-admins@kubernetes.io": {
			"ameukam@gmail.com",
			"davanum@gmail.com",
			"ihor@cncf.io",
			"spiffxp@google.com",
			"thockin@google.com",
		},
		"k8s-infra-group-admins@kubernetes.io": {
			"ameukam@gmail.com",
			"cblecker@gmail.com",
			"davanum@gmail.com",
			"nikhitaraghunath@gmail.com",
			"spiffxp@google.com",
			"thockin@google.com",
		},
	}

	found := make(map[string]bool)

	for _, g := range groupsConfig.Groups {
		if expected, ok := groups[g.EmailId]; ok {
			found[g.EmailId] = true
			sort.Strings(expected)
			actual := make([]string, len(g.Members))
			copy(actual, g.Members)
			sort.Strings(actual)
			if !reflect.DeepEqual(expected, actual) {
				errs = append(errs, fmt.Errorf("group '%s': expected members '%v', got '%v'", g.Name, expected, actual))
			}
		}
	}

	for email := range groups {
		if _, ok := found[email]; !ok {
			errs = append(errs, fmt.Errorf("group '%s' is missing, should be present", email))
		}
	}

	return utilerrors.NewAggregate(errs)
}

// Setting AllowWebPosting should be set for every group which should support
// access to the group not only via gmail but also via web (you can see the list
// and history of threads and also use web interface to operate the group)
// More info:
// 	https://developers.google.com/admin-sdk/groups-settings/v1/reference/groups#allowWebPosting

// TODO: I'd love to make this more general to enforce that groups matching a certain
// pattern must have web history / web posting.
// https://github.com/kubernetes/k8s.io/pull/3407#discussion_r808645808

func VerifyGroupsWhichShouldSupportHistory(groupsConfig GroupsConfig) error {
	// aggregate the errors that occured and return them together in the end.
	var errs []error

	groups := map[string]struct{}{
		"leads@kubernetes.io": {},
	}

	found := make(map[string]struct{})
	for _, group := range groupsConfig.Groups {
		emailID := group.EmailId
		found[emailID] = struct{}{}
		if _, ok := groups[emailID]; ok {
			allowedWebPosting, ok := group.Settings["AllowWebPosting"]
			if !ok {
				errs = append(errs, fmt.Errorf(
					"group '%s': must have 'settings.allowedWebPosting = true'",
					group.Name,
				))
			} else if allowedWebPosting != "true" {
				errs = append(errs, fmt.Errorf(
					"group '%s': must have 'settings.allowedWebPosting = true'"+
						" but have 'settings.allowedWebPosting = %s' instead",
					group.Name,
					allowedWebPosting,
				))
			}
		}
	}

	for email := range groups {
		if _, ok := found[email]; !ok {
			errs = append(errs, fmt.Errorf("group '%s' is missing, should be present", email))
		}
	}

	return utilerrors.NewAggregate(errs)
}
