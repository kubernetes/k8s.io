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
	"strings"
	"testing"
	"unicode/utf8"
)

// TestStagingEmailLength tests that the number of characters in the
// project name in emails used for staging repos does not exceed 18.
//
// This validation is needed because gcloud allows PROJECT_IDs of length
// between 6 and 30. So after discounting the "k8s-staging" prefix,
// we are left with 18 chars for the project name.
func TestStagingEmailLength(t *testing.T) {
	var cfg GroupsConfig
	if err := readGroupsConfig("groups.yaml", &cfg); err != nil {
		t.Fatal(err)
	}

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
