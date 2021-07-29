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
	"reflect"
	"testing"
)

func TestRestrictionForPath(t *testing.T) {
	rc := &RestrictionsConfig{
		Restrictions: []Restriction{
			{
				Path: "full-path-to-sig-foo/file.yaml",
				AllowedGroups: []string{
					"sig-foo-group-a",
					"sig-foo-group-b",
				},
			},
		},
	}
	testcases := []struct {
		name           string
		path           string
		expectedPath   string
		expectedGroups []string
	}{
		{
			name:           "empty path",
			path:           "",
			expectedPath:   "*",
			expectedGroups: nil,
		},
		{
			name:         "full path match",
			path:         "full-path-to-sig-foo/file.yaml",
			expectedPath: "full-path-to-sig-foo/file.yaml",
			expectedGroups: []string{
				"sig-foo-group-a",
				"sig-foo-group-b",
			},
		},
		{
			name:           "path not found",
			path:           "does-not/exist.yaml",
			expectedPath:   "*",
			expectedGroups: nil,
		},
	}

	for _, tc := range testcases {
		t.Run(tc.name, func(t *testing.T) {
			path := tc.path
			root := "root" // TODO: add testcases that vary root
			expected := Restriction{
				Path:          tc.expectedPath,
				AllowedGroups: tc.expectedGroups,
			}
			actual := rc.GetRestrictionForPath(path, root)
			if expected.Path != actual.Path {
				t.Errorf("Unexpected restriction.path for %v, %v: expected %v, got %v", path, root, expected.Path, actual.Path)
			}
			if !reflect.DeepEqual(expected.AllowedGroups, actual.AllowedGroups) {
				t.Errorf("Unexpected restriction.allowedGroups for %v, %v: expected %v, got %v", path, root, expected.AllowedGroups, actual.AllowedGroups)
			}
		})
	}
}
