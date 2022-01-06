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

package fake

import (
	"fmt"

	admin "google.golang.org/api/admin/directory/v1"
	groupssettings "google.golang.org/api/groupssettings/v1"
)

// FakeAdminServiceClient implements the AdminServiceClient but is fake.
type FakeAdminServiceClient struct {
	// Groups is a mapping from groupKey to *admin.Group
	Groups map[string]*admin.Group
	// Members is a mapping from groupKey -> members of that group
	// Members of a group are a mapping from memberKey -> *admin.Member
	Members map[string]map[string]*admin.Member
	// OnGroupInsert is a callback function called whenever an
	// Insert operation is done for a group. This is nescessary
	// because creating a group also involves reflecting that
	// creation in the group service fake client, where the GsGroups
	// map takes the group email as the key.
	onGroupInsert func(string)
}

func NewFakeAdminServiceClient() *FakeAdminServiceClient {
	return &FakeAdminServiceClient{
		Groups:  make(map[string]*admin.Group),
		Members: make(map[string]map[string]*admin.Member),
	}
}

func NewAugmentedFakeAdminServiceClient() *FakeAdminServiceClient {
	fakeClient := NewFakeAdminServiceClient()
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
				Role:  "MEMBER",
				Id:    "m1-group1@email.com",
			},
			"m2-group1@email.com": {
				Email: "m2-group1@email.com",
				Role:  "MANAGER",
				Id:    "m2-group1@email.com",
			},
		},
		"group2@email.com": {
			"m1-group2@email.com": {
				Email: "m1-group2@email.com",
				Role:  "MEMBER",
				Id:    "m1-group2@email.com",
			},
			"m2-group2@email.com": {
				Email: "m2-group2@email.com",
				Role:  "OWNER",
				Id:    "m2-group2@email.com",
			},
		},
	}

	return fakeClient
}

func (fasc *FakeAdminServiceClient) RegisterCallback(onGroupInsert func(string)) {
	fasc.onGroupInsert = onGroupInsert
}

func (fasc *FakeAdminServiceClient) GetGroup(groupKey string) (*admin.Group, error) {
	group, ok := fasc.Groups[groupKey]
	if !ok {
		return nil, fmt.Errorf("group key %s not found", groupKey)
	}

	return group, nil
}

func (fasc *FakeAdminServiceClient) GetMember(groupKey, memberKey string) (*admin.Member, error) {
	members, ok := fasc.Members[groupKey]
	if !ok {
		return nil, fmt.Errorf("group with group key %s not found", groupKey)
	}

	member, ok := members[memberKey]
	if !ok {
		return nil, fmt.Errorf("member with groupKey %s and memberKey %s not found", groupKey, memberKey)
	}

	return member, nil
}

func (fasc *FakeAdminServiceClient) ListGroups() (*admin.Groups, error) {
	groups := &admin.Groups{}
	for _, group := range fasc.Groups {
		groups.Groups = append(groups.Groups, group)
	}
	return groups, nil
}

func (fasc *FakeAdminServiceClient) ListMembers(groupKey string) ([]*admin.Member, error) {
	_, ok := fasc.Members[groupKey]
	if !ok {
		return nil, fmt.Errorf("groupKey %s not found", groupKey)
	}

	members := &admin.Members{}
	for _, member := range fasc.Members[groupKey] {
		members.Members = append(members.Members, member)
	}

	return members.Members, nil
}

func (fasc *FakeAdminServiceClient) InsertGroup(group *admin.Group) (*admin.Group, error) {
	fasc.Groups[group.Email] = group
	if fasc.onGroupInsert != nil {
		fasc.onGroupInsert(group.Email)
	}

	fasc.Members[group.Email] = map[string]*admin.Member{}
	return group, nil
}

func (fasc *FakeAdminServiceClient) InsertMember(groupKey string, member *admin.Member) (*admin.Member, error) {
	_, ok := fasc.Members[groupKey]
	if !ok {
		return nil, fmt.Errorf("groupKey %s not found", groupKey)
	}

	fasc.Members[groupKey][member.Email] = member
	return member, nil
}

func (fasc *FakeAdminServiceClient) UpdateGroup(groupKey string, group *admin.Group) (*admin.Group, error) {
	_, ok := fasc.Groups[groupKey]
	if !ok {
		return nil, fmt.Errorf("group key %s not found", groupKey)
	}

	fasc.Groups[groupKey] = group
	return group, nil
}

func (fasc *FakeAdminServiceClient) UpdateMember(groupKey, memberKey string, member *admin.Member) (*admin.Member, error) {
	_, ok := fasc.Members[groupKey]
	if !ok {
		return nil, fmt.Errorf("group with group key %s not found", groupKey)
	}

	_, ok = fasc.Members[groupKey][memberKey]
	if !ok {
		return nil, fmt.Errorf("member with groupKey %s and memberKey %s not found", groupKey, memberKey)
	}

	fasc.Members[groupKey][memberKey] = member
	return member, nil
}

func (fasc *FakeAdminServiceClient) DeleteGroup(groupKey string) error {
	_, ok := fasc.Groups[groupKey]
	if !ok {
		return fmt.Errorf("group key %s not found", groupKey)
	}

	delete(fasc.Groups, groupKey)
	return nil
}

func (fasc *FakeAdminServiceClient) DeleteMember(groupKey, memberKey string) error {
	_, ok := fasc.Members[groupKey]
	if !ok {
		return fmt.Errorf("group with group key %s not found", groupKey)
	}

	_, ok = fasc.Members[groupKey][memberKey]
	if !ok {
		return fmt.Errorf("member with groupKey %s and memberKey %s not found", groupKey, memberKey)
	}

	delete(fasc.Members[groupKey], memberKey)
	return nil
}

// FakeGroupServiceClient implements the GroupServiceClient but is fake.
type FakeGroupServiceClient struct {
	GsGroups map[string]*groupssettings.Groups
}

func NewFakeGroupServiceClient() *FakeGroupServiceClient {
	return &FakeGroupServiceClient{
		GsGroups: make(map[string]*groupssettings.Groups),
	}
}

func NewAugmentedFakeGroupServiceClient() *FakeGroupServiceClient {
	fakeClient := NewFakeGroupServiceClient()
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

func (fgsc *FakeGroupServiceClient) Get(groupUniqueID string) (*groupssettings.Groups, error) {
	gsg, ok := fgsc.GsGroups[groupUniqueID]
	if !ok {
		return nil, fmt.Errorf("groupUniqueID not found %ss", groupUniqueID)
	}

	return gsg, nil
}

func (fgsc *FakeGroupServiceClient) Patch(groupUniqueID string, groups *groupssettings.Groups) (*groupssettings.Groups, error) {
	_, ok := fgsc.GsGroups[groupUniqueID]
	if !ok {
		return nil, fmt.Errorf("groupUniqueID not found %ss", groupUniqueID)
	}

	fgsc.GsGroups[groupUniqueID] = groups
	return groups, nil
}
