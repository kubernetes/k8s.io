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
	"strings"

	admin "google.golang.org/api/admin/directory/v1"
	"google.golang.org/api/googleapi"
	groupssettings "google.golang.org/api/groupssettings/v1"
	"google.golang.org/api/option"
	utilerrors "k8s.io/apimachinery/pkg/util/errors"
)

const (
	OwnerRole   = "OWNER"
	ManagerRole = "MANAGER"
	MemberRole  = "MEMBER"
)

// AdminService provides functionality to perform high level
// tasks using a AdminServiceClient.
type AdminService interface {
	AddOrUpdateGroupMembers(group GoogleGroup, role string, members []string) error
	CreateOrUpdateGroupIfNescessary(group GoogleGroup) error
	DeleteGroupsIfNecessary() error
	RemoveOwnerOrManagersFromGroup(group GoogleGroup, members []string) error
	RemoveMembersFromGroup(group GoogleGroup, members []string) error
	// ListGroup here is a proxy to the ListGroups method of the underlying
	// AdminServiceClient being used.
	ListGroups() (*admin.Groups, error)
	// ListMembers here is a proxy to the ListMembers method of the underlying
	// AdminServiceClient being used.
	ListMembers(groupKey string) ([]*admin.Member, error)
}

// GroupService provides functionality to perform high level
// tasks using a GroupServiceClient.
type GroupService interface {
	UpdateGroupSettings(group GoogleGroup) error
	// Get here is a proxy to the Get method of the
	// underlying GroupServiceClient
	Get(groupUniqueID string) (*groupssettings.Groups, error)
}

func NewAdminService(ctx context.Context, clientOption option.ClientOption) (AdminService, error) {
	client, err := NewAdminServiceClient(ctx, clientOption)
	if err != nil {
		return nil, err
	}

	return NewAdminServiceWithClient(client)
}

func NewAdminServiceWithClient(client AdminServiceClient) (AdminService, error) {
	errFunc := func(err error) bool {
		apierr, ok := err.(*googleapi.Error)
		return ok && apierr.Code == http.StatusNotFound
	}
	return &adminService{
		client:            client,
		checkForAPIErr404: errFunc,
	}, nil
}

func NewAdminServiceWithClientAndErrFunc(client AdminServiceClient, errFunc clientErrCheckFunc) (AdminService, error) {
	return &adminService{
		client:            client,
		checkForAPIErr404: errFunc,
	}, nil
}

func NewGroupService(ctx context.Context, clientOption option.ClientOption) (GroupService, error) {
	client, err := NewGroupServiceClient(ctx, clientOption)
	if err != nil {
		return nil, err
	}

	return NewGroupServiceWithClient(client)
}

func NewGroupServiceWithClient(client GroupServiceClient) (GroupService, error) {
	errFunc := func(err error) bool {
		apierr, ok := err.(*googleapi.Error)
		return ok && apierr.Code == http.StatusNotFound
	}
	return &groupService{
		client:            client,
		checkForAPIErr404: errFunc,
	}, nil
}

func NewGroupServiceWithClientAndErrFunc(client GroupServiceClient, errFunc clientErrCheckFunc) (GroupService, error) {
	return &groupService{
		client:            client,
		checkForAPIErr404: errFunc,
	}, nil
}

// clientErrCheckFunc is stubbed out here for testing
// purposes in order to implement custome error checking
// logic. This function is used to check errors returned
// by the client. The boolean return signifies if the
// check for the error passed or not.
type clientErrCheckFunc func(error) bool

type adminService struct {
	client            AdminServiceClient
	checkForAPIErr404 clientErrCheckFunc
}

// AddOrUpdateGroupMembers first lists all members that are part of group. Based on this list and the
// members, it will update the member in the group (if needed) or if the member is not found in the
// list, it will create the member.
func (as *adminService) AddOrUpdateGroupMembers(group GoogleGroup, role string, members []string) error {
	if *verbose {
		log.Printf("adminService.AddOrUpdateGroupMembers %s %s %v", group.EmailId, role, members)
	}

	l, err := as.client.ListMembers(group.EmailId)
	if err != nil {
		if as.checkForAPIErr404(err) {
			log.Printf("skipping adding members to group %q as it has not yet been created\n", group.EmailId)
			return nil
		}
		return fmt.Errorf("unable to retrieve members in group %q: %w", group.EmailId, err)
	}

	// aggregate the errors that occurred and return them together in the end.
	var errs []error

	for _, memberEmailId := range members {
		var member *admin.Member
		for _, m := range l {
			if EmailAddressEquals(m.Email, memberEmailId) {
				member = m
				break
			}
		}

		if member != nil {
			// update if necessary
			if member.Role != role {
				member.Role = role
				if config.ConfirmChanges {
					log.Printf("Updating %s to %q as a %s\n", memberEmailId, group.EmailId, role)
					_, err := as.client.UpdateMember(group.EmailId, member.Email, member)
					if err != nil {
						logErr := fmt.Errorf("unable to update %s in %q as %s: %w", memberEmailId, group.EmailId, role, err)
						log.Printf("%s\n", logErr)
						errs = append(errs, logErr)
						continue
					}
					log.Printf("Updated %s to %q as a %s\n", memberEmailId, group.EmailId, role)
				} else {
					log.Printf("dry-run: would update %s to %q as %s\n", memberEmailId, group.EmailId, role)
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
			log.Printf("Adding %s to %q as a %s\n", memberEmailId, group.EmailId, role)
			_, err := as.client.InsertMember(group.EmailId, member)
			if err != nil {
				logErr := fmt.Errorf("unable to add %s to %q as %s: %w", memberEmailId, group.EmailId, role, err)
				log.Printf("%s\n", logErr)
				errs = append(errs, logErr)
				continue
			}
			log.Printf("Added %s to %q as a %s\n", memberEmailId, group.EmailId, role)
		} else {
			log.Printf("dry-run: would add %s to %q as %s\n", memberEmailId, group.EmailId, role)
		}
	}

	return utilerrors.NewAggregate(errs)
}

// CreateOrUpdateGroupIfNescessary will create a group if the provided group's email ID
// does not already exist. If it exists, it will update the group if needed to match the
// provided group.
func (as *adminService) CreateOrUpdateGroupIfNescessary(group GoogleGroup) error {
	if *verbose {
		log.Printf("adminService.CreateOrUpdateGroupIfNecessary %s", group.EmailId)
	}

	grp, err := as.client.GetGroup(group.EmailId)
	if err != nil {
		if as.checkForAPIErr404(err) {
			if !config.ConfirmChanges {
				log.Printf("dry-run: would create group %q\n", group.EmailId)
			} else {
				log.Printf("Trying to create group: %q\n", group.EmailId)
				g := admin.Group{
					Email: group.EmailId,
				}
				if group.Name != "" {
					g.Name = group.Name
				}
				if group.Description != "" {
					g.Description = group.Description
				}
				g4, err := as.client.InsertGroup(&g)
				if err != nil {
					return fmt.Errorf("unable to add new group %q: %w", group.EmailId, err)
				}
				log.Printf("> Successfully created group %s\n", g4.Email)
			}
		} else {
			return fmt.Errorf("unable to fetch group %q: %w", group.EmailId, err)
		}
	} else {
		if group.Name != "" && grp.Name != group.Name ||
			group.Description != "" && grp.Description != group.Description {
			if !config.ConfirmChanges {
				log.Printf("dry-run: would update group name/description %q\n", group.EmailId)
			} else {
				log.Printf("Trying to update group: %q\n", group.EmailId)
				g := admin.Group{
					Email: group.EmailId,
				}
				if group.Name != "" {
					g.Name = group.Name
				}
				if group.Description != "" {
					g.Description = group.Description
				}
				g4, err := as.client.UpdateGroup(group.EmailId, &g)
				if err != nil {
					return fmt.Errorf("unable to update group %q: %w", group.EmailId, err)
				}
				log.Printf("> Successfully updated group %s\n", g4.Email)
			}
		}
	}
	return nil
}

// DeleteGroupsIfNecessary checks against the groups config provided by the user. It
// first lists all existing groups, if a group in this list does not appear in the
// provided group config, it will delete this group to match the desired state.
func (as *adminService) DeleteGroupsIfNecessary() error {
	g, err := as.client.ListGroups()
	if err != nil {
		return fmt.Errorf("unable to retrieve users in domain: %w", err)
	}

	// aggregate the errors that occurred and return them together in the end.
	var errs []error

	for _, g := range g.Groups {
		found := false
		for _, g2 := range groupsConfig.Groups {
			if EmailAddressEquals(g2.EmailId, g.Email) {
				found = true
				break
			}
		}
		if found {
			continue
		}

		// We did not find the group in our groups.xml, so delete the group
		if config.ConfirmChanges {
			log.Printf("Deleting group %s", g.Email)
			err := as.client.DeleteGroup(g.Email)
			if err != nil {
				errs = append(errs, fmt.Errorf("unable to remove group %s : %w", g.Email, err))
				continue
			}
			log.Printf("Removed group %s\n", g.Email)
		} else {
			log.Printf("dry-run: would remove group %s\n", g.Email)
		}

	}

	return utilerrors.NewAggregate(errs)
}

// RemoveOwnerOrManagersFromGroup lists members of the group and checks against the list of members
// passed. If a member from the retrieved list of members does not exist in the passed list of members,
// this member is removed - provided this member had a OWNER/MANAGER role.
func (as *adminService) RemoveOwnerOrManagersFromGroup(group GoogleGroup, members []string) error {
	if *verbose {
		log.Printf("adminService.RemoveOwnerOrManagersGroup %s %v", group.EmailId, members)
	}
	l, err := as.client.ListMembers(group.EmailId)
	if err != nil {
		if as.checkForAPIErr404(err) {
			log.Printf("skipping removing members group %q as group has not yet been created\n", group.EmailId)
			return nil
		}
		return fmt.Errorf("unable to retrieve members in group %q: %w", group.EmailId, err)
	}

	// aggregate the errors that occurred and return them together in the end.
	var errs []error

	for _, m := range l {
		found := false
		for _, m2 := range members {
			if EmailAddressEquals(m2, m.Email) {
				found = true
				break
			}
		}

		// If a member m exists in our desired list of members, do nothing.
		// However, if this member m does not exist in our desired list of
		// members but is in the role of a MEMBER (non OWNER/MANAGER), still
		// do nothing since we care only about OWNER/MANAGER roles here.
		if found || m.Role == MemberRole {
			continue
		}

		// a person was deleted from a group, let's remove them
		if config.ConfirmChanges {
			log.Printf("Removing %s from %q as OWNER or MANAGER\n", m.Email, group.EmailId)
			err := as.client.DeleteMember(group.EmailId, m.Id)
			if err != nil {
				logErr := fmt.Errorf("unable to remove %s from %q as a %s: %w", m.Email, group.EmailId, m.Role, err)
				log.Printf("%s\n", logErr)
				errs = append(errs, logErr)
				continue
			}
			log.Printf("Removed %s from %q as OWNER or MANAGER\n", m.Email, group.EmailId)
		} else {
			log.Printf("dry-run: would remove %s from %q as OWNER or MANAGER\n", m.Email, group.EmailId)
		}
	}

	return utilerrors.NewAggregate(errs)
}

// RemoveMembersFromGroup lists members of the group and checks against the list of members passed.
// If a member from the retrieved list of members does not exist in the passed list of members, this
// member is removed. Unlike RemoveOwnerOrManagersFromGroup, RemoveMembersFromGroup will remove the
// member regardless of the role that the member held.
func (as *adminService) RemoveMembersFromGroup(group GoogleGroup, members []string) error {
	if *verbose {
		log.Printf("adminService.RemoveMembersFromGroup %s %v", group.EmailId, members)
	}
	l, err := as.client.ListMembers(group.EmailId)
	if err != nil {
		if as.checkForAPIErr404(err) {
			log.Printf("skipping removing members group %q as group has not yet been created\n", group.EmailId)
			return nil
		}
		return fmt.Errorf("unable to retrieve members in group %q: %w", group.EmailId, err)
	}

	// aggregate the errors that occurred and return them together in the end.
	var errs []error

	for _, m := range l {
		found := false
		for _, m2 := range members {
			if EmailAddressEquals(m2, m.Email) {
				found = true
				break
			}
		}
		if found {
			continue
		}

		// a person was deleted from a group, let's remove them
		if config.ConfirmChanges {
			log.Printf("Removing %s from %q as a %s\n", m.Email, group.EmailId, m.Role)
			err := as.client.DeleteMember(group.EmailId, m.Id)
			if err != nil {
				logErr := fmt.Errorf("unable to remove %s from %q as a %s: %w", m.Email, group.EmailId, m.Role, err)
				log.Printf("%s\n", logErr)
				errs = append(errs, logErr)
				continue
			}
			log.Printf("Removed %s from %q as a %s\n", m.Email, group.EmailId, m.Role)
		} else {
			log.Printf("dry-run: would remove %s from %q as a %s\n", m.Email, group.EmailId, m.Role)
		}
	}

	return utilerrors.NewAggregate(errs)
}

// ListGroups lists all the groups available.
func (as *adminService) ListGroups() (*admin.Groups, error) {
	return as.client.ListGroups()
}

// ListMembers lists all the members of a group with a particular groupKey.
func (as *adminService) ListMembers(groupKey string) ([]*admin.Member, error) {
	return as.client.ListMembers(groupKey)
}

var _ AdminService = (*adminService)(nil)

type groupService struct {
	client            GroupServiceClient
	checkForAPIErr404 clientErrCheckFunc
}

// UpdateGroupSettings updates the groupsettings.Groups corresponding to the
// passed group based on what the current state of the groupsetting.Groups is.
func (gs *groupService) UpdateGroupSettings(group GoogleGroup) error {
	if *verbose {
		log.Printf("groupService.UpdateGroupSettings %s", group.EmailId)
	}
	g2, err := gs.client.Get(group.EmailId)
	if err != nil {
		if gs.checkForAPIErr404(err) {
			log.Printf("skipping updating group settings as group %q has not yet been created\n", group.EmailId)
			return nil
		}
		return fmt.Errorf("unable to retrieve group info for group %q: %w", group.EmailId, err)
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

	for key, value := range group.Settings {
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
			_, err := gs.client.Patch(group.EmailId, &wantSettings)
			if err != nil {
				return fmt.Errorf("unable to update group info for group %q: %w", group.EmailId, err)
			}
			log.Printf("> Successfully updated group settings for %q to allow external members and other security settings\n", group.EmailId)
		} else {
			log.Printf("dry-run: would update group settings for %q\n", group.EmailId)
			log.Printf("dry-run: current settings %+q", haveSettings)
			log.Printf("dry-run: desired settings %+q", wantSettings)
		}
	}

	return nil
}

// Get retrieves the group settings of a group with groupUniqueID.
func (gs *groupService) Get(groupUniqueID string) (*groupssettings.Groups, error) {
	return gs.client.Get(groupUniqueID)
}

var _ GroupService = (*groupService)(nil)

// DeepCopy deepcopies a to b using json marshaling. This discards fields like
// the server response that don't have a specifc json field name.
func deepCopySettings(a, b interface{}) {
	byt, _ := json.Marshal(a)
	json.Unmarshal(byt, b)
}

// EmailAddressEquals checks equivalence between two e-mail addresses according
// to the following rules:
// - email addresses are case-insensitive (e.g. FOO@bar.com == foo@bar.com)
// - local parts are dot-inensitive (e.g. foo@bar.com == f.o.o@bar.com)
func EmailAddressEquals(a, b string) bool {
	// if they match case-insensitive, don't bother checking dot-insensitive
	if strings.EqualFold(a, b) {
		return true
	}
	aParts := strings.Split(a, "@")
	bParts := strings.Split(b, "@")
	// These aren't valid e-mail addresses if they don't have exactly one @
	// and we already know they're not case-insensitively equal, so return false
	if len(aParts) != 2 || len(bParts) != 2 {
		return false
	}
	// strip dots from local parts and case-insensitively compare the resulting
	// email addresses
	aLocal := strings.ReplaceAll(aParts[0], ".", "")
	bLocal := strings.ReplaceAll(bParts[0], ".", "")
	return strings.EqualFold(aLocal+"@"+aParts[1], bLocal+"@"+bParts[1])
}
