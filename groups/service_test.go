/*
Copyright 2021 The Kubernetes Authors.

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

	admin "google.golang.org/api/admin/directory/v1"
	groupssettings "google.golang.org/api/groupssettings/v1"
	"k8s.io/k8s.io/groups/fake"
)

func augmentAdminServiceFakeClient(fakeClient *fake.FakeAdminServiceClient) *fake.FakeAdminServiceClient {
	fakeClient.Groups = map[string]*admin.Group{
		"group1@email.com": {
			Email:       "group1@email.com",
			Name:        "group1",
			Description: "group1",
		},
		"group2@email.com": {
			Email:       "group2@email.com",
			Name:        "group2",
			Description: "group2",
		},
	}

	fakeClient.Members = map[string]map[string]*admin.Member{
		"group1@email.com": {
			"m1-group1@email.com": {
				Email: "m1-group1@email.com",
				Role:  MemberRole,
				Id:    "m1-group1@email.com",
			},
			"m2-group1@email.com": {
				Email: "m2-group1@email.com",
				Role:  ManagerRole,
				Id:    "m2-group1@email.com",
			},
		},
		"group2@email.com": {
			"m1-group2@email.com": {
				Email: "m1-group2@email.com",
				Role:  MemberRole,
				Id:    "m1-group2@email.com",
			},
			"m2-group2@email.com": {
				Email: "m2-group2@email.com",
				Role:  OwnerRole,
				Id:    "m2-group2@email.com",
			},
		},
	}

	return fakeClient
}

func augmentGroupServiceFakeClient(fakeClient *fake.FakeGroupServiceClient) *fake.FakeGroupServiceClient {
	fakeClient.GsGroups = map[string]*groupssettings.Groups{
		"group1@email.com": {
			AllowExternalMembers:     "true",
			WhoCanJoin:               "CAN_REQUEST_TO_JOIN",
			WhoCanViewMembership:     "ALL_MANAGERS_CAN_VIEW",
			WhoCanViewGroup:          "ALL_MEMBERS_CAN_VIEW",
			WhoCanDiscoverGroup:      "ALL_IN_DOMAIN_CAN_DISCOVER",
			WhoCanModerateMembers:    "OWNERS_AND_MANAGERS",
			WhoCanModerateContent:    "OWNERS_AND_MANAGERS",
			WhoCanPostMessage:        "ALL_MEMBERS_CAN_POST",
			MessageModerationLevel:   "MODERATE_NONE",
			MembersCanPostAsTheGroup: "true",
		},
		"group2@email.com": {
			AllowExternalMembers:     "true",
			WhoCanJoin:               "INVITED_CAN_JOIN",
			WhoCanViewMembership:     "ALL_MANAGERS_CAN_VIEW",
			WhoCanViewGroup:          "ALL_MEMBERS_CAN_VIEW",
			WhoCanDiscoverGroup:      "ALL_IN_DOMAIN_CAN_DISCOVER",
			WhoCanModerateMembers:    "OWNERS_ONLY",
			WhoCanModerateContent:    "OWNERS_AND_MANAGERS",
			WhoCanPostMessage:        "ALL_MEMBERS_CAN_POST",
			MessageModerationLevel:   "MODERATE_NONE",
			MembersCanPostAsTheGroup: "false",
		},
	}

	return fakeClient
}

// This checks for equality of two member lists based on two things:
// 1. Email ID
// 2. Role
func checkForMemberListEquality(a, b []*admin.Member) bool {
	if len(a) != len(b) {
		return false
	}

	bMap := make(map[string]*admin.Member)
	for i := 0; i < len(b); i++ {
		bMap[b[i].Email] = b[i]
	}

	for i := 0; i < len(a); i++ {
		if inB, ok := bMap[a[i].Email]; ok {
			if inB.Role != a[i].Role {
				return false
			}
			continue
		}
		return false
	}

	return true
}

// This checks for equality of two group lists based on three things:
// 1. Email ID
// 2. Name
// 3. Descirption
func checkForGroupListEquality(a, b []*admin.Group) bool {
	if len(a) != len(b) {
		return false
	}

	bMap := make(map[string]*admin.Group)
	for i := 0; i < len(b); i++ {
		bMap[b[i].Email] = b[i]
	}

	for i := 0; i < len(a); i++ {
		if inB, ok := bMap[a[i].Email]; ok {
			if inB.Name != a[i].Name || inB.Description != a[i].Description {
				return false
			}
			continue
		}
		return false
	}

	return true
}

// This checks for equality of one admin.Group list and one GoogleGroup list based on 3 things:
// 1. Email ID
// 2. Name
// 3. Descirption
func checkForAdminGroupGoogleGroupEquality(a []*admin.Group, b []GoogleGroup) bool {
	if len(a) != len(b) {
		return false
	}

	bMap := make(map[string]GoogleGroup)
	for i := 0; i < len(b); i++ {
		bMap[b[i].EmailId] = b[i]
	}

	for i := 0; i < len(a); i++ {
		if inB, ok := bMap[a[i].Email]; ok {
			if inB.Name != a[i].Name || inB.Description != a[i].Description {
				return false
			}
			continue
		}
		return false
	}

	return true
}

func getMemberListInPrintableForm(members []*admin.Member) []admin.Member {
	res := make([]admin.Member, len(members))
	for i := 0; i < len(res); i++ {
		res[i] = *members[i]
	}

	return res
}

func getGroupListInPrintableForm(groups []*admin.Group) []admin.Group {
	res := make([]admin.Group, len(groups))
	for i := 0; i < len(res); i++ {
		res[i] = *groups[i]
	}

	return res
}

func TestAddOrUpdateGroupMembers(t *testing.T) {
	config.ConfirmChanges = true
	cases := []struct {
		desc            string
		g               GoogleGroup
		members         []string
		expectedMembers []*admin.Member
		role            string
	}{
		{
			desc:    "all members already exist, no create/update",
			g:       GoogleGroup{EmailId: "group1@email.com"},
			members: []string{"m1-group1@email.com"},
			expectedMembers: []*admin.Member{
				{Email: "m1-group1@email.com", Role: MemberRole},
				{Email: "m2-group1@email.com", Role: ManagerRole},
			},
			role: MemberRole,
		},
		{
			desc:    "new members to add, create operation",
			g:       GoogleGroup{EmailId: "group1@email.com"},
			members: []string{"new-group1@email.com"},
			expectedMembers: []*admin.Member{
				{Email: "m1-group1@email.com", Role: MemberRole},
				{Email: "m2-group1@email.com", Role: ManagerRole},
				{Email: "new-group1@email.com", Role: MemberRole},
			},
			role: MemberRole,
		},
		{
			desc:    "change member role, update operation",
			g:       GoogleGroup{EmailId: "group1@email.com"},
			members: []string{"m1-group1@email.com"},
			expectedMembers: []*admin.Member{
				{Email: "m1-group1@email.com", Role: OwnerRole},
				{Email: "m2-group1@email.com", Role: ManagerRole},
			},
			role: OwnerRole,
		},
	}

	errFunc = func(err error) bool {
		return err != nil
	}
	for _, c := range cases {
		fakeClient := fake.NewFakeAdminServiceClient()
		fakeClient = augmentAdminServiceFakeClient(fakeClient)

		adminSvc, err := NewAdminServiceWithClient(fakeClient)
		if err != nil {
			t.Errorf("error creating client %w", err)
		}
		err = adminSvc.AddOrUpdateGroupMembers(c.g, c.role, c.members)
		if err != nil {
			t.Errorf("error while executing AddOrUpdateGroupMembers for case %s: %s", c.desc, err.Error())
		}

		result, err := fakeClient.ListMembers(c.g.EmailId)
		if err != nil {
			t.Errorf("error while listing members for groupKey %s and case %s: %w", c.g.EmailId, c.desc, err)
		}
		if !checkForMemberListEquality(result.Members, c.expectedMembers) {
			t.Errorf("unexpected list of members for %s, expected: %#v, got: %#v",
				c.desc,
				getMemberListInPrintableForm(c.expectedMembers),
				getMemberListInPrintableForm(result.Members),
			)
		}
	}
}

func TestCreateOrUpdateGroupIfNescessary(t *testing.T) {
	config.ConfirmChanges = true
	cases := []struct {
		desc           string
		g              GoogleGroup
		expectedGroups []*admin.Group
	}{
		{
			desc: "group already exists, do nothing",
			g:    GoogleGroup{EmailId: "group1@email.com", Name: "group1", Description: "group1"},
			expectedGroups: []*admin.Group{
				{Email: "group1@email.com", Name: "group1", Description: "group1"},
				{Email: "group2@email.com", Name: "group2", Description: "group2"},
			},
		},
		{
			desc: "group does not exist, add group",
			g:    GoogleGroup{EmailId: "group3@email.com", Name: "group3", Description: "group3"},
			expectedGroups: []*admin.Group{
				{Email: "group1@email.com", Name: "group1", Description: "group1"},
				{Email: "group2@email.com", Name: "group2", Description: "group2"},
				{Email: "group3@email.com", Name: "group3", Description: "group3"},
			},
		},
		{
			desc: "group exists, but group name was modified, update group",
			g:    GoogleGroup{EmailId: "group1@email.com", Name: "group1New", Description: "group1"},
			expectedGroups: []*admin.Group{
				{Email: "group1@email.com", Name: "group1New", Description: "group1"},
				{Email: "group2@email.com", Name: "group2", Description: "group2"},
			},
		},
		{
			desc: "group exists, but group description was modified, update group",
			g:    GoogleGroup{EmailId: "group1@email.com", Name: "group1", Description: "group1New"},
			expectedGroups: []*admin.Group{
				{Email: "group1@email.com", Name: "group1", Description: "group1New"},
				{Email: "group2@email.com", Name: "group2", Description: "group2"},
			},
		},
	}

	errFunc = func(err error) bool {
		return err != nil
	}
	for _, c := range cases {
		fakeClient := fake.NewFakeAdminServiceClient()
		fakeClient = augmentAdminServiceFakeClient(fakeClient)

		adminSvc, err := NewAdminServiceWithClient(fakeClient)
		if err != nil {
			t.Errorf("error creating client %w", err)
		}

		err = adminSvc.CreateOrUpdateGroupIfNescessary(c.g)
		if err != nil {
			t.Errorf("error while executing CreateOrUpdateGroupIfNescessary for case %s: %s", c.desc, err.Error())
		}

		result, err := fakeClient.ListGroups()
		if err != nil {
			t.Errorf("error while listing groups for case %s: %w", c.desc, err)
		}

		if !checkForGroupListEquality(result.Groups, c.expectedGroups) {
			t.Errorf("unexpected list of groups for %s, expected: %#v, got: %#v",
				c.desc,
				getGroupListInPrintableForm(c.expectedGroups),
				getGroupListInPrintableForm(result.Groups),
			)
		}
	}
}

func TestDeleteGroupsIfNecessary(t *testing.T) {
	config.ConfirmChanges = true
	cases := []struct {
		desc         string
		desiredState []GoogleGroup
	}{
		{
			desc: "states match, nothing to reconcile",
			desiredState: []GoogleGroup{
				{EmailId: "group1@email.com", Name: "group1", Description: "group1"},
				{EmailId: "group2@email.com", Name: "group2", Description: "group2"},
			},
		},
		{
			desc: "mismatch in desired state, delete group3 group",
			desiredState: []GoogleGroup{
				{EmailId: "group1@email.com", Name: "group1", Description: "group1"},
				{EmailId: "group2@email.com", Name: "group2", Description: "group2"},
			},
		},
	}

	errFunc = func(err error) bool {
		return err != nil
	}
	for _, c := range cases {
		fakeClient := fake.NewFakeAdminServiceClient()
		fakeClient = augmentAdminServiceFakeClient(fakeClient)

		adminSvc, err := NewAdminServiceWithClient(fakeClient)
		if err != nil {
			t.Errorf("error creating client %w", err)
		}
		groupsConfig.Groups = c.desiredState

		err = adminSvc.DeleteGroupsIfNecessary()
		if err != nil {
			t.Errorf("error while executing DeleteGroupsIfNecessary for case %s: %s", c.desc, err.Error())
		}

		result, err := fakeClient.ListGroups()
		if err != nil {
			t.Errorf("error while listing groups for case %s: %w", c.desc, err)
		}

		if !checkForAdminGroupGoogleGroupEquality(result.Groups, c.desiredState) {
			t.Errorf("unexpected list of groups for %s, expected: %#v, got: %#v",
				c.desc,
				c.desiredState,
				getGroupListInPrintableForm(result.Groups),
			)
		}
	}
}

func TestRemoveOwnerOrManagersFromGroup(t *testing.T) {
	config.ConfirmChanges = true
	cases := []struct {
		desc            string
		g               GoogleGroup
		desiredState    []string
		expectedMembers []*admin.Member
	}{
		{
			desc:         "state matches, no deletion",
			g:            GoogleGroup{EmailId: "group1@email.com"},
			desiredState: []string{"m1-group1@email.com", "m2-group1@email.com"},
			expectedMembers: []*admin.Member{
				{Email: "m1-group1@email.com", Role: MemberRole},
				{Email: "m2-group1@email.com", Role: ManagerRole},
			},
		},
		{
			desc:         "state does not match, but member to delete has MEMBER role, skip deletion",
			g:            GoogleGroup{EmailId: "group1@email.com"},
			desiredState: []string{"m2-group1@email.com"},
			expectedMembers: []*admin.Member{
				{Email: "m1-group1@email.com", Role: MemberRole},
				{Email: "m2-group1@email.com", Role: ManagerRole},
			},
		},
		{
			desc:         "state does not match, member to delete is OWNER/MANAGER, perform deletion",
			g:            GoogleGroup{EmailId: "group1@email.com"},
			desiredState: []string{"m1-group1@email.com"},
			expectedMembers: []*admin.Member{
				{Email: "m1-group1@email.com", Role: MemberRole},
			},
		},
	}

	errFunc = func(err error) bool {
		return err != nil
	}
	for _, c := range cases {
		fakeClient := fake.NewFakeAdminServiceClient()
		fakeClient = augmentAdminServiceFakeClient(fakeClient)

		adminSvc, err := NewAdminServiceWithClient(fakeClient)
		if err != nil {
			t.Errorf("error creating client %w", err)
		}

		err = adminSvc.RemoveOwnerOrManagersFromGroup(c.g, c.desiredState)
		if err != nil {
			t.Errorf("error while executing RemoveOwnerOrManagersFromGroup for case %s: %s", c.desc, err.Error())
		}

		result, err := fakeClient.ListMembers(c.g.EmailId)
		if err != nil {
			t.Errorf("error while listing members for groupKey %s and case %s: %w", c.g.EmailId, c.desc, err)
		}

		if !checkForMemberListEquality(result.Members, c.expectedMembers) {
			t.Errorf("unexpected list of members for %s, expected: %#v, got: %#v",
				c.desc,
				getMemberListInPrintableForm(c.expectedMembers),
				getMemberListInPrintableForm(result.Members),
			)
		}
	}
}

func TestRemoveMembersFromGroup(t *testing.T) {
	config.ConfirmChanges = true
	cases := []struct {
		desc            string
		g               GoogleGroup
		desiredState    []string
		expectedMembers []*admin.Member
	}{
		{
			desc:         "state matches, no deletion",
			g:            GoogleGroup{EmailId: "group1@email.com"},
			desiredState: []string{"m1-group1@email.com", "m2-group1@email.com"},
			expectedMembers: []*admin.Member{
				{Email: "m1-group1@email.com", Role: MemberRole},
				{Email: "m2-group1@email.com", Role: ManagerRole},
			},
		},
		{
			desc:         "state does not match, member to delete in MEMBER role, perform deletion",
			g:            GoogleGroup{EmailId: "group1@email.com"},
			desiredState: []string{"m2-group1@email.com"},
			expectedMembers: []*admin.Member{
				{Email: "m2-group1@email.com", Role: ManagerRole},
			},
		},
		{
			desc:         "state does not match, member to delete is OWNER/MANAGER, perform deletion",
			g:            GoogleGroup{EmailId: "group1@email.com"},
			desiredState: []string{"m1-group1@email.com"},
			expectedMembers: []*admin.Member{
				{Email: "m1-group1@email.com", Role: MemberRole},
			},
		},
	}

	errFunc = func(err error) bool {
		return err != nil
	}
	for _, c := range cases {
		fakeClient := fake.NewFakeAdminServiceClient()
		fakeClient = augmentAdminServiceFakeClient(fakeClient)

		adminSvc, err := NewAdminServiceWithClient(fakeClient)
		if err != nil {
			t.Errorf("error creating client %w", err)
		}

		err = adminSvc.RemoveMembersFromGroup(c.g, c.desiredState)
		if err != nil {
			t.Errorf("error while executing RemoveMembersFromGroup for case %s: %s", c.desc, err.Error())
		}

		result, err := fakeClient.ListMembers(c.g.EmailId)
		if err != nil {
			t.Errorf("error while listing members for groupKey %s and case %s: %w", c.g.EmailId, c.desc, err)
		}

		if !checkForMemberListEquality(result.Members, c.expectedMembers) {
			t.Errorf("unexpected list of members for %s, expected: %#v, got: %#v",
				c.desc,
				getMemberListInPrintableForm(c.expectedMembers),
				getMemberListInPrintableForm(result.Members),
			)
		}
	}
}

func TestUpdateGroupSettings(t *testing.T) {
	config.ConfirmChanges = true
	cases := []struct {
		desc             string
		g                GoogleGroup
		expectedSettings *groupssettings.Groups
	}{
		{
			desc: "group settings match, no change",
			g: GoogleGroup{
				EmailId: "group1@email.com",
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
			},
			expectedSettings: &groupssettings.Groups{
				AllowExternalMembers:     "true",
				WhoCanJoin:               "CAN_REQUEST_TO_JOIN",
				WhoCanViewMembership:     "ALL_MANAGERS_CAN_VIEW",
				WhoCanViewGroup:          "ALL_MEMBERS_CAN_VIEW",
				WhoCanDiscoverGroup:      "ALL_IN_DOMAIN_CAN_DISCOVER",
				WhoCanModerateMembers:    "OWNERS_AND_MANAGERS",
				WhoCanModerateContent:    "OWNERS_AND_MANAGERS",
				WhoCanPostMessage:        "ALL_MEMBERS_CAN_POST",
				MessageModerationLevel:   "MODERATE_NONE",
				MembersCanPostAsTheGroup: "true",
			},
		},
		{
			desc: "group settings don't match, attempt to update",
			g: GoogleGroup{
				EmailId: "group1@email.com",
				Settings: map[string]string{
					"AllowExternalMembers":     "true",
					"WhoCanJoin":               "CAN_REQUEST_TO_JOIN",
					"WhoCanViewMembership":     "ALL_MANAGERS_CAN_VIEW",
					"WhoCanViewGroup":          "ALL_MEMBERS_CAN_VIEW",
					"WhoCanDiscoverGroup":      "ALL_IN_DOMAIN_CAN_DISCOVER",
					"WhoCanModerateMembers":    "OWNERS_ONLY",
					"WhoCanModerateContent":    "OWNERS_AND_MANAGERS",
					"WhoCanPostMessage":        "ALL_MEMBERS_CAN_POST",
					"MessageModerationLevel":   "MODERATE_NONE",
					"MembersCanPostAsTheGroup": "false",
				},
			},
			expectedSettings: &groupssettings.Groups{
				AllowExternalMembers:     "true",
				WhoCanJoin:               "CAN_REQUEST_TO_JOIN",
				WhoCanViewMembership:     "ALL_MANAGERS_CAN_VIEW",
				WhoCanViewGroup:          "ALL_MEMBERS_CAN_VIEW",
				WhoCanDiscoverGroup:      "ALL_IN_DOMAIN_CAN_DISCOVER",
				WhoCanModerateMembers:    "OWNERS_ONLY",
				WhoCanModerateContent:    "OWNERS_AND_MANAGERS",
				WhoCanPostMessage:        "ALL_MEMBERS_CAN_POST",
				MessageModerationLevel:   "MODERATE_NONE",
				MembersCanPostAsTheGroup: "false",
			},
		},
		{
			desc: "group settings don't match, attempt to update (test for defaults being set)",
			g:    GoogleGroup{EmailId: "group1@email.com", Settings: map[string]string{}},
			expectedSettings: &groupssettings.Groups{
				AllowExternalMembers:     "true",
				WhoCanJoin:               "INVITED_CAN_JOIN",
				WhoCanViewMembership:     "ALL_MANAGERS_CAN_VIEW",
				WhoCanViewGroup:          "ALL_MEMBERS_CAN_VIEW",
				WhoCanDiscoverGroup:      "ALL_IN_DOMAIN_CAN_DISCOVER",
				WhoCanModerateMembers:    "OWNERS_AND_MANAGERS",
				WhoCanModerateContent:    "OWNERS_AND_MANAGERS",
				WhoCanPostMessage:        "ALL_MEMBERS_CAN_POST",
				MessageModerationLevel:   "MODERATE_NONE",
				MembersCanPostAsTheGroup: "false",
			},
		},
	}

	errFunc = func(err error) bool {
		return err != nil
	}
	for _, c := range cases {
		fakeClient := fake.NewFakeGroupServiceClient()
		fakeClient = augmentGroupServiceFakeClient(fakeClient)

		groupSvc, err := NewGroupServiceWithClient(fakeClient)
		if err != nil {
			t.Errorf("error creating client %w", err)
		}

		err = groupSvc.UpdateGroupSettings(c.g)
		if err != nil {
			t.Errorf("error while executing UpdateGroupSettings for case %s: %s", c.desc, err.Error())
		}

		result, err := fakeClient.Get(c.g.EmailId)
		if err != nil {
			t.Errorf("error while getting groupsettings of group with groupKey %s: %w", c.g.EmailId, err)
		}

		if !reflect.DeepEqual(result, c.expectedSettings) {
			t.Errorf("unexpected groupsettings for case %s, expected: %#v, got: %#v", c.desc, c.expectedSettings, result)
		}
	}
}
