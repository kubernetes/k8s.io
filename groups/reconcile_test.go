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
	"reflect"
	"testing"

	admin "google.golang.org/api/admin/directory/v1"
	groupssettings "google.golang.org/api/groupssettings/v1"
	"k8s.io/k8s.io/groups/fake"
)

// state is used to hold information needed
// to construct the state of the world.
type state struct {
	adminClient AdminServiceClient
	groupClient GroupServiceClient
}

// isReconciled constructs the current state of the world using adminClient
// and groupClient and checks if it is reconciled against the desiredState
// and matches it.
func (s state) isReconciled(desiredState []GoogleGroup) error {
	// incrementally construct the state of the world and check
	// against the desiredState.
	// see if the groups that exist are reconciled or not.
	res, _ := s.adminClient.ListGroups()
	if !checkForAdminGroupGoogleGroupEquality(res.Groups, desiredState) {
		return fmt.Errorf(
			"groups do not match (email, name, description): desired: %#v, actual: %#v",
			desiredState,
			constructGoogleGroupFromAdminGroup(res.Groups),
		)
	}

	// now that we know that atleast the groups that exist are the same, we
	// create a map of emailID -> *admin.Group to make sure we are checking
	// the same group in every iteration of the next step.
	currGroups := make(map[string]*admin.Group)
	for i, g := range res.Groups {
		currGroups[g.Email] = res.Groups[i]
	}

	// provided the groups that exist are the same, check for member equality
	// and groupSettings.Group equality.
	for i := 0; i < len(desiredState); i++ {
		// safe to assume that the EmailID will exist as a key because
		// we already checked if the groups that exist are the same or
		// not.
		currGroup := currGroups[desiredState[i].EmailId]
		desiredMembers := constructMemberListFromGoogleGroup(desiredState[i])
		currentMembers, err := s.adminClient.ListMembers(currGroup.Email)
		if err != nil {
			return err
		}
		if !checkForMemberListEquality(desiredMembers, currentMembers) {
			return fmt.Errorf(
				"member lists do not match (email, role): desired: %#v, actual: %#v",
				getMemberListInPrintableForm(desiredMembers),
				getMemberListInPrintableForm(currentMembers),
			)
		}
		currentSettings, err := s.groupClient.Get(currGroup.Email)
		if err != nil {
			return err
		}
		desiredSettings := constructGroupSettingsFromGoogleGroup(desiredState[i])
		if !reflect.DeepEqual(desiredSettings, currentSettings) {
			return fmt.Errorf(
				"group settings do not match, desired: %#v, actual: %#v",
				desiredSettings,
				currentSettings,
			)
		}
	}

	return nil
}

func constructMemberListFromGoogleGroup(g GoogleGroup) []*admin.Member {
	res := make([]*admin.Member, len(g.Members)+len(g.Managers)+len(g.Owners))
	index := 0
	for _, m := range g.Members {
		res[index] = &admin.Member{Email: m, Id: m, Role: MemberRole}
		index++
	}
	for _, m := range g.Managers {
		res[index] = &admin.Member{Email: m, Id: m, Role: ManagerRole}
		index++
	}
	for _, m := range g.Owners {
		res[index] = &admin.Member{Email: m, Id: m, Role: OwnerRole}
		index++
	}

	return res
}

func constructGroupSettingsFromGoogleGroup(g GoogleGroup) *groupssettings.Groups {
	requiredSettingsDefaults := map[string]string{
		"AllowExternalMembers":     "true",
		"WhoCanJoin":               "INVITED_CAN_JOIN",
		"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
		"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
		"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
		"WhoCanModerateMembers":    "OWNERS_AND_MANAGERS",
		"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
		"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
		"MessageModerationLevel":   "MODERATE_NONE",
		"MembersCanPostAsTheGroup": "false",
	}

	for s, v := range requiredSettingsDefaults {
		if _, ok := g.Settings[s]; !ok {
			g.Settings[s] = v
		}
	}

	return &groupssettings.Groups{
		AllowExternalMembers:     g.Settings["AllowExternalMembers"],
		WhoCanJoin:               g.Settings["WhoCanJoin"],
		WhoCanViewMembership:     g.Settings["WhoCanViewMembership"],
		WhoCanViewGroup:          g.Settings["WhoCanViewGroup"],
		WhoCanDiscoverGroup:      g.Settings["WhoCanDiscoverGroup"],
		WhoCanModerateMembers:    g.Settings["WhoCanModerateMembers"],
		WhoCanModerateContent:    g.Settings["WhoCanModerateContent"],
		WhoCanPostMessage:        g.Settings["WhoCanPostMessage"],
		MessageModerationLevel:   g.Settings["MessageModerationLevel"],
		MembersCanPostAsTheGroup: g.Settings["MembersCanPostAsTheGroup"],
	}
}

func constructGoogleGroupFromAdminGroup(ag []*admin.Group) []GoogleGroup {
	res := make([]GoogleGroup, len(ag))
	for i := 0; i < len(res); i++ {
		res[i] = GoogleGroup{EmailId: ag[i].Email, Name: ag[i].Name, Description: ag[i].Description}
	}

	return res
}

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

func TestReconcileGroups(t *testing.T) {
	config.ConfirmChanges = true
	cases := []struct {
		desc string
		// desired state is not nescessarily the same as expected state.
		// We might need the two of them to differ in cases where we want
		// to test out functionality where our desired state warrants for
		// a change but in actuality this change should not occur - which
		// is signified via expected state. shouldConsiderExpectedState is
		// what differentiates what we should consider when comparing results.
		// If false - desired is same as expected. This is done because in
		// most cases these two are same and we can avoid clutter.
		shouldConsiderExpectedState bool
		desiredState                []GoogleGroup
		expectedState               []GoogleGroup
	}{
		{
			desc: "state matches, nothing to reconcile",
			desiredState: []GoogleGroup{
				{
					EmailId: "group1@email.com", Name: "group1", Description: "group1",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "CAN_REQUEST_TO_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_AND_MANAGERS",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "true",
					},
					Members:  []string{"m1-group1@email.com"},
					Managers: []string{"m2-group1@email.com"},
				},
				{
					EmailId: "group2@email.com", Name: "group2", Description: "group2",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "INVITED_CAN_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_ONLY",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "false",
					},
					Members: []string{"m1-group2@email.com"},
					Owners:  []string{"m2-group2@email.com"},
				},
			},
		},
		{
			desc: "new members added, attempt to reconcile",
			desiredState: []GoogleGroup{
				{
					EmailId: "group1@email.com", Name: "group1", Description: "group1",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "CAN_REQUEST_TO_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_AND_MANAGERS",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "true",
					},
					Members:  []string{"m1-group1@email.com"},
					Managers: []string{"m2-group1@email.com"},
					Owners:   []string{"m3-group1@email.com"}, // new member
				},
				{
					EmailId: "group2@email.com", Name: "group2", Description: "group2",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "INVITED_CAN_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_ONLY",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "false",
					},
					Members:  []string{"m1-group2@email.com"},
					Managers: []string{"m3-group2@email.com"}, // new member
					Owners:   []string{"m2-group2@email.com"},
				},
			},
		},
		{
			desc: "members with OWNER/MANAGER role deleted from group1 and group2, attempt to reconcile",
			desiredState: []GoogleGroup{
				{
					EmailId: "group1@email.com", Name: "group1", Description: "group1",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "CAN_REQUEST_TO_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_AND_MANAGERS",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "true",
					},
					Members:  []string{"m1-group1@email.com"},
					Managers: []string{}, // member removed
				},
				{
					EmailId: "group2@email.com", Name: "group2", Description: "group2",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "INVITED_CAN_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_ONLY",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "false",
					},
					Members: []string{"m1-group2@email.com"},
					Owners:  []string{}, // member removed
				},
			},
		},
		{
			desc: "member with MANAGER role deleted in group1 and member with MEMBER role added in group2, attempt to reconcile",
			desiredState: []GoogleGroup{
				{
					EmailId: "group1@email.com", Name: "group1", Description: "group1",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "CAN_REQUEST_TO_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_AND_MANAGERS",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "true",
					},
					Members:  []string{"m1-group1@email.com"},
					Managers: []string{}, // member removed
				},
				{
					EmailId: "group2@email.com", Name: "group2", Description: "group2",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "INVITED_CAN_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_ONLY",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "false",
					},
					Members: []string{"m1-group2@email.com", "m3-group2@email.com"}, // member added
					Owners:  []string{"m2-group2@email.com"},
				},
			},
		},
		{
			desc: "member with MEMBER role deleted from group1 with ReconcileMembers setting enabled, attempt to reconcile",
			desiredState: []GoogleGroup{
				{
					EmailId: "group1@email.com", Name: "group1", Description: "group1",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "CAN_REQUEST_TO_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_AND_MANAGERS",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "true",
						"ReconcileMembers":         "true",
					},
					Members:  []string{}, // member removed
					Managers: []string{"m2-group1@email.com"},
				},
				{
					EmailId: "group2@email.com", Name: "group2", Description: "group2",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "INVITED_CAN_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_ONLY",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "false",
					},
					Members: []string{"m1-group2@email.com"},
					Owners:  []string{"m2-group2@email.com"},
				},
			},
		},
		{
			desc: "member with MEMBER role deleted from group1 with ReconcileMembers setting disabled, no change",
			desiredState: []GoogleGroup{
				{
					EmailId: "group1@email.com", Name: "group1", Description: "group1",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "CAN_REQUEST_TO_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_AND_MANAGERS",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "true",
						"ReconcileMembers":         "false",
					},
					Members:  []string{}, // member removed
					Managers: []string{"m2-group1@email.com"},
				},
				{
					EmailId: "group2@email.com", Name: "group2", Description: "group2",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "INVITED_CAN_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_ONLY",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "false",
					},
					Members: []string{"m1-group2@email.com"},
					Owners:  []string{"m2-group2@email.com"},
				},
			},
			shouldConsiderExpectedState: true,
			expectedState: []GoogleGroup{
				{
					EmailId: "group1@email.com", Name: "group1", Description: "group1",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "CAN_REQUEST_TO_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_AND_MANAGERS",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "true",
						"ReconcileMembers":         "false", // setting disabled.
					},
					Members:  []string{"m1-group1@email.com"}, // member not removed.
					Managers: []string{"m2-group1@email.com"},
				},
				{
					EmailId: "group2@email.com", Name: "group2", Description: "group2",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "INVITED_CAN_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_ONLY",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "false",
					},
					Members: []string{"m1-group2@email.com"},
					Owners:  []string{"m2-group2@email.com"},
				},
			},
		},
		{
			desc: "group2 deleted, attempt to reconcile",
			desiredState: []GoogleGroup{
				{
					EmailId: "group1@email.com", Name: "group1", Description: "group1",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "CAN_REQUEST_TO_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_AND_MANAGERS",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "true",
					},
					Members:  []string{"m1-group1@email.com"},
					Managers: []string{"m2-group1@email.com"},
				},
			},
		},
		{
			desc: "group3 added, member with OWNER role added to group1 and member with MANAGER role added to group2",
			desiredState: []GoogleGroup{
				{
					EmailId: "group1@email.com", Name: "group1", Description: "group1",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "CAN_REQUEST_TO_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_AND_MANAGERS",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "true",
					},
					Members:  []string{"m1-group1@email.com"},
					Managers: []string{"m2-group1@email.com"},
					Owners:   []string{"m3-group1@email.com"}, // member added
				},
				{
					EmailId: "group2@email.com", Name: "group2", Description: "group2",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "INVITED_CAN_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_ONLY",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "false",
					},
					Members:  []string{"m1-group2@email.com"},
					Owners:   []string{"m2-group2@email.com"},
					Managers: []string{"m3-group2@email.com"}, // member added
				},
				{
					// group added
					EmailId: "group3@email.com", Name: "group3", Description: "group3",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "CAN_REQUEST_TO_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_AND_MANAGERS",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "true",
					},
					Members:  []string{"m1-group3@email.com"},
					Managers: []string{"m2-group3@email.com"},
					Owners:   []string{"m3-group3@email.com"},
				},
			},
		},
		{
			desc: "move member from MEMBER role in group1 to OWNER role.",
			desiredState: []GoogleGroup{
				{
					EmailId: "group1@email.com", Name: "group1", Description: "group1",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "CAN_REQUEST_TO_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_AND_MANAGERS",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "true",
					},
					Members:  []string{},
					Managers: []string{"m2-group1@email.com"},
					Owners:   []string{"m1-group1@email.com"},
				},
				{
					EmailId: "group2@email.com", Name: "group2", Description: "group2",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "INVITED_CAN_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_ONLY",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "false",
					},
					Members: []string{"m1-group2@email.com"},
					Owners:  []string{"m2-group2@email.com"},
				},
			},
		},
		{
			desc: "move member from OWNER role in group2 to MEMBER role.",
			desiredState: []GoogleGroup{
				{
					EmailId: "group1@email.com", Name: "group1", Description: "group1",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "CAN_REQUEST_TO_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_AND_MANAGERS",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "true",
					},
					Members:  []string{"m1-group1@email.com"},
					Managers: []string{"m2-group1@email.com"},
				},
				{
					EmailId: "group2@email.com", Name: "group2", Description: "group2",
					Settings: map[string]string{
						"AllowExternalMembers":     "true",
						"WhoCanJoin":               "INVITED_CAN_JOIN",
						"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
						"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
						"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
						"WhoCanModerateMembers":    "OWNERS_ONLY",
						"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
						"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
						"MessageModerationLevel":   "MODERATE_NONE",
						"MembersCanPostAsTheGroup": "false",
					},
					Members: []string{"m1-group2@email.com", "m2-group2@email.com"},
					Owners:  []string{},
				},
			},
		},
	}

	errFunc := func(err error) bool {
		return err != nil
	}
	for _, c := range cases {
		groupsConfig.Groups = c.desiredState
		fakeAdminClient := fake.NewAugmentedFakeAdminServiceClient()
		fakeGroupClient := fake.NewAugmentedFakeGroupServiceClient()

		fakeAdminClient.RegisterCallback(func(groupKey string) {
			_, ok := fakeGroupClient.GsGroups[groupKey]
			if !ok {
				fakeGroupClient.GsGroups[groupKey] = &groupssettings.Groups{}
			}
		})

		adminSvc, _ := NewAdminServiceWithClientAndErrFunc(fakeAdminClient, errFunc)
		groupSvc, _ := NewGroupServiceWithClientAndErrFunc(fakeGroupClient, errFunc)

		reconciler := &Reconciler{adminService: adminSvc, groupService: groupSvc}
		err := reconciler.ReconcileGroups(c.desiredState)
		if err != nil {
			t.Errorf("error reconciling groups for case %s: %s", c.desc, err.Error())
		}

		s := state{adminClient: fakeAdminClient, groupClient: fakeGroupClient}

		var expectedState []GoogleGroup
		if c.shouldConsiderExpectedState {
			expectedState = c.expectedState
		} else {
			expectedState = c.desiredState
		}
		if err = s.isReconciled(expectedState); err != nil {
			t.Errorf("reconciliation unsuccessful for case %s: %v", c.desc, err)
		}
	}
}
