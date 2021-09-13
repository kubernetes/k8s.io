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
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"reflect"

	admin "google.golang.org/api/admin/directory/v1"
	"google.golang.org/api/googleapi"
	groupssettings "google.golang.org/api/groupssettings/v1"
	"google.golang.org/api/option"
)

type Service interface {
	SetGroup(GoogleGroup)
}

type AdminService interface {
	Service
	AddOrUpdateGroupMembers(role string, members []string) error
	CreateOrUpdateGroupIfNescessary() error
	DeleteGroupsIfNecessary() error
	RemoveOwnerOrManagersFromGroup(members []string) error
	RemoveMembersFromGroup(members []string) error
	GetClient() AdminServiceClient
}

type GroupService interface {
	Service
	UpdateGroupSettings() error
	GetClient() GroupServiceClient
}

func NewAdminService(ctx context.Context, clientOption option.ClientOption) (AdminService, error) {
	client, err := NewAdminServiceClient(ctx, clientOption)
	if err != nil {
		return nil, err
	}

	return &adminService{client: client}, nil
}

func NewGroupService(ctx context.Context, clientOption option.ClientOption) (GroupService, error) {
	client, err := NewGroupServiceClient(ctx, clientOption)
	if err != nil {
		return nil, err
	}

	return &groupService{client: client}, nil
}

type adminService struct {
	client AdminServiceClient
	group  GoogleGroup
}

func (as *adminService) SetGroup(group GoogleGroup) {
	as.group = group
}

func (as *adminService) AddOrUpdateGroupMembers(role string, members []string) error {
	if *verbose {
		log.Printf("addOrUpdateMembersToGroup %s %q %v", role, as.group.EmailId, members)
	}

	l, err := as.client.ListMembers(as.group.EmailId)
	if err != nil {
		if apierr, ok := err.(*googleapi.Error); ok && apierr.Code == http.StatusNotFound {
			log.Printf("skipping adding members to group %q as it has not yet been created\n", as.group.EmailId)
			return nil
		}
		return fmt.Errorf("unable to retrieve members in group %q: %v", as.group.EmailId, err)
	}

	for _, memberEmailId := range members {
		var member *admin.Member
		for _, m := range l.Members {
			if m.Email == memberEmailId {
				member = m
				break
			}
		}

		if member != nil {
			// update if necessary
			if member.Role != role {
				member.Role = role
				if config.ConfirmChanges {
					_, err := as.client.UpdateMember(as.group.EmailId, member.Email, member)
					if err != nil {
						return fmt.Errorf("unable to update %s in %q as %s : %v", memberEmailId, as.group.EmailId, role, err)
					}
					log.Printf("Updated %s to %q as a %s\n", memberEmailId, as.group.EmailId, role)
				} else {
					log.Printf("dry-run: would update %s to %q as %s\n", memberEmailId, as.group.EmailId, role)
				}
			}
			continue
		}
		member = &admin.Member{
			Email: memberEmailId,
			Role:  role,
		}

		// We did not find the person in the google group, so we add them
		if config.ConfirmChanges {
			_, err := as.client.InsertMember(as.group.EmailId, member)
			if err != nil {
				return fmt.Errorf("unable to add %s to %q as %s : %v", memberEmailId, as.group.EmailId, role, err)
			}
			log.Printf("Added %s to %q as a %s\n", memberEmailId, as.group.EmailId, role)
		} else {
			log.Printf("dry-run: would add %s to %q as %s\n", memberEmailId, as.group.EmailId, role)
		}
	}

	return nil
}

func (as *adminService) CreateOrUpdateGroupIfNescessary() error {
	if *verbose {
		log.Printf("createOrUpdateGroupIfNecessary %q", as.group.EmailId)
	}

	group, err := as.client.GetGroup(as.group.EmailId)
	if err != nil {
		if apierr, ok := err.(*googleapi.Error); ok && apierr.Code == http.StatusNotFound {
			if !config.ConfirmChanges {
				log.Printf("dry-run: would create group %q\n", as.group.EmailId)
			} else {
				log.Printf("Trying to create group: %q\n", as.group.EmailId)
				g := admin.Group{
					Email: as.group.EmailId,
				}
				if as.group.Name != "" {
					g.Name = as.group.Name
				}
				if as.group.Description != "" {
					g.Description = as.group.Description
				}
				g4, err := as.client.InsertGroup(&g)
				if err != nil {
					return fmt.Errorf("unable to add new group %q: %v", as.group.EmailId, err)
				}
				log.Printf("> Successfully created group %s\n", g4.Email)
			}
		} else {
			return fmt.Errorf("unable to fetch group %q: %#v", as.group.EmailId, err.Error())
		}
	} else {
		if as.group.Name != "" && group.Name != as.group.Name ||
			as.group.Description != "" && group.Description != as.group.Description {
			if !config.ConfirmChanges {
				log.Printf("dry-run: would update group name/description %q\n", as.group.EmailId)
			} else {
				log.Printf("Trying to update group: %q\n", as.group.EmailId)
				g := admin.Group{
					Email: as.group.EmailId,
				}
				if as.group.Name != "" {
					g.Name = as.group.Name
				}
				if as.group.Description != "" {
					g.Description = as.group.Description
				}
				g4, err := as.client.UpdateGroup(as.group.EmailId, &g)
				if err != nil {
					return fmt.Errorf("unable to update group %q: %v", as.group.EmailId, err)
				}
				log.Printf("> Successfully updated group %s\n", g4.Email)
			}
		}
	}
	return nil
}

func (as *adminService) DeleteGroupsIfNecessary() error {
	g, err := as.client.ListGroups()
	if err != nil {
		return fmt.Errorf("unable to retrieve users in domain: %v", err)
	}
	if len(g.Groups) == 0 {
		log.Println("No groups found.")
		return nil
	}

	for _, g := range g.Groups {
		found := false
		for _, g2 := range groupsConfig.Groups {
			if g2.EmailId == g.Email {
				found = true
				break
			}
		}
		if found {
			continue
		}

		// We did not find the group in our groups.xml, so delete the group
		if config.ConfirmChanges {
			if *verbose {
				log.Printf("deleting group %s", g.Email)
			}
			err := as.client.DeleteGroup(g.Email)
			if err != nil {
				return fmt.Errorf("unable to remove group %s : %v", g.Email, err)
			}
			log.Printf("Removing group %s\n", g.Email)
		} else {
			log.Printf("dry-run: would remove group %s\n", g.Email)
		}

	}

	return nil
}

func (as *adminService) RemoveOwnerOrManagersFromGroup(members []string) error {
	if *verbose {
		log.Printf("removeOwnerOrManagersGroup %q %v", as.group.EmailId, members)
	}
	l, err := as.client.ListMembers(as.group.EmailId)
	if err != nil {
		if apierr, ok := err.(*googleapi.Error); ok && apierr.Code == http.StatusNotFound {
			log.Printf("skipping removing members group %q as group has not yet been created\n", as.group.EmailId)
			return nil
		}
		return fmt.Errorf("unable to retrieve members in group %q: %v", as.group.EmailId, err)
	}

	for _, m := range l.Members {
		found := false
		for _, m2 := range members {
			if m2 == m.Email {
				found = true
				break
			}
		}
		if found || m.Role == "MEMBER" {
			continue
		}
		// a person was deleted from a group, let's remove them
		if config.ConfirmChanges {
			err := as.client.DeleteMember(as.group.EmailId, m.Id)
			if err != nil {
				return fmt.Errorf("unable to remove %s from %q as OWNER or MANAGER : %v", m.Email, as.group.EmailId, err)
			}
			log.Printf("Removing %s from %q as OWNER or MANAGER\n", m.Email, as.group.EmailId)
		} else {
			log.Printf("dry-run: would remove %s from %q as OWNER or MANAGER\n", m.Email, as.group.EmailId)
		}
	}
	return nil
}

func (as *adminService) RemoveMembersFromGroup(members []string) error {
	if *verbose {
		log.Printf("removeMembersFromGroup %q %v", as.group.EmailId, members)
	}
	l, err := as.client.ListMembers(as.group.EmailId)
	if err != nil {
		if apierr, ok := err.(*googleapi.Error); ok && apierr.Code == http.StatusNotFound {
			log.Printf("skipping removing members group %q as group has not yet been created\n", as.group.EmailId)
			return nil
		}
		return fmt.Errorf("unable to retrieve members in group %q: %v", as.group.EmailId, err)
	}

	for _, m := range l.Members {
		found := false
		for _, m2 := range members {
			if m2 == m.Email {
				found = true
				break
			}
		}
		if found {
			continue
		}
		// a person was deleted from a group, let's remove them
		if config.ConfirmChanges {
			err := as.client.DeleteMember(as.group.EmailId, m.Id)
			if err != nil {
				return fmt.Errorf("unable to remove %s from %q as a %s : %v", m.Email, as.group.EmailId, m.Role, err)
			}
			log.Printf("Removing %s from %q as a %s\n", m.Email, as.group.EmailId, m.Role)
		} else {
			log.Printf("dry-run: would remove %s from %q as a %s\n", m.Email, as.group.EmailId, m.Role)
		}
	}
	return nil
}

func (as *adminService) GetClient() AdminServiceClient {
	return as.client
}

var _ AdminService = (*adminService)(nil)

type groupService struct {
	client GroupServiceClient
	group  GoogleGroup
}

func (gs *groupService) SetGroup(group GoogleGroup) {
	gs.group = group
}

func (gs *groupService) UpdateGroupSettings() error {
	if *verbose {
		log.Printf("updateGroupSettings %q", gs.group.EmailId)
	}
	g2, err := gs.client.Get(gs.group.EmailId)
	if err != nil {
		if apierr, ok := err.(*googleapi.Error); ok && apierr.Code == http.StatusNotFound {
			log.Printf("skipping updating group settings as group %q has not yet been created\n", gs.group.EmailId)
			return nil
		}
		return fmt.Errorf("unable to retrieve group info for group %q: %v", gs.group.EmailId, err)
	}

	var (
		haveSettings groupssettings.Groups
		wantSettings groupssettings.Groups
	)

	// We copy the settings we get from the API into haveSettings, and then copy
	// it again into wantSettings so we have a version we can manipulate.
	deepCopySettings(&g2, &haveSettings)
	deepCopySettings(&haveSettings, &wantSettings)

	// This sets safe/sane defaults
	wantSettings.AllowExternalMembers = "true"
	wantSettings.WhoCanJoin = "INVITED_CAN_JOIN"
	wantSettings.WhoCanViewMembership = "ALL_MANAGERS_CAN_VIEW"
	wantSettings.WhoCanViewGroup = "ALL_MEMBERS_CAN_VIEW"
	wantSettings.WhoCanDiscoverGroup = "ALL_IN_DOMAIN_CAN_DISCOVER"
	wantSettings.WhoCanModerateMembers = "OWNERS_AND_MANAGERS"
	wantSettings.WhoCanModerateContent = "OWNERS_AND_MANAGERS"
	wantSettings.WhoCanPostMessage = "ALL_MEMBERS_CAN_POST"
	wantSettings.MessageModerationLevel = "MODERATE_NONE"
	wantSettings.MembersCanPostAsTheGroup = "false"

	for key, value := range gs.group.Settings {
		switch key {
		case "AllowExternalMembers":
			wantSettings.AllowExternalMembers = value
		case "AllowWebPosting":
			wantSettings.AllowWebPosting = value
		case "WhoCanJoin":
			wantSettings.WhoCanJoin = value
		case "WhoCanViewMembership":
			wantSettings.WhoCanViewMembership = value
		case "WhoCanViewGroup":
			wantSettings.WhoCanViewGroup = value
		case "WhoCanDiscoverGroup":
			wantSettings.WhoCanDiscoverGroup = value
		case "WhoCanModerateMembers":
			wantSettings.WhoCanModerateMembers = value
		case "WhoCanPostMessage":
			wantSettings.WhoCanPostMessage = value
		case "MessageModerationLevel":
			wantSettings.MessageModerationLevel = value
		case "MembersCanPostAsTheGroup":
			wantSettings.MembersCanPostAsTheGroup = value
		}
	}

	if !reflect.DeepEqual(&haveSettings, &wantSettings) {
		if config.ConfirmChanges {
			_, err := gs.client.Patch(gs.group.EmailId, &wantSettings)
			if err != nil {
				return fmt.Errorf("unable to update group info for group %q: %v", gs.group.EmailId, err)
			}
			log.Printf("> Successfully updated group settings for %q to allow external members and other security settings\n", gs.group.EmailId)
		} else {
			log.Printf("dry-run: would update group settings for %q\n", gs.group.EmailId)
			log.Printf("dry-run: current settings %+q", haveSettings)
			log.Printf("dry-run: desired settings %+q", wantSettings)
		}
	}
	return nil
}

func (gs *groupService) GetClient() GroupServiceClient {
	return gs.client
}

var _ GroupService = (*groupService)(nil)

// DeepCopy deepcopies a to b using json marshaling. This discards fields like
// the server response that don't have a specifc json field name.
func deepCopySettings(a, b interface{}) {
	byt, _ := json.Marshal(a)
	json.Unmarshal(byt, b)
}
