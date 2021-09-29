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

	admin "google.golang.org/api/admin/directory/v1"
	groupssettings "google.golang.org/api/groupssettings/v1"
	"google.golang.org/api/option"
)

type AdminServiceClient interface {
	GetGroup(groupKey string) (*admin.Group, error)
	GetMember(groupKey, memberKey string) (*admin.Member, error)
	ListGroups() (*admin.Groups, error)
	ListMembers(groupKey string) (*admin.Members, error)
	InsertGroup(group *admin.Group) (*admin.Group, error)
	InsertMember(groupKey string, member *admin.Member) (*admin.Member, error)
	UpdateGroup(groupKey string, group *admin.Group) (*admin.Group, error)
	UpdateMember(groupKey, memberKey string, member *admin.Member) (*admin.Member, error)
	DeleteGroup(groupKey string) error
	DeleteMember(groupKey, memberKey string) error
}

func NewAdminServiceClient(ctx context.Context, clientOption option.ClientOption) (AdminServiceClient, error) {
	adminSvc, err := admin.NewService(ctx, clientOption)
	if err != nil {
		return nil, err
	}

	return &adminServiceClient{service: adminSvc}, nil
}

type adminServiceClient struct {
	service *admin.Service
}

func (asc *adminServiceClient) GetGroup(groupKey string) (*admin.Group, error) {
	return asc.service.Groups.Get(groupKey).Do()
}

func (asc *adminServiceClient) GetMember(groupKey, memberKey string) (*admin.Member, error) {
	return asc.service.Members.Get(groupKey, memberKey).Do()
}

func (asc *adminServiceClient) ListGroups() (*admin.Groups, error) {
	return asc.service.Groups.List().Customer("my_customer").OrderBy("email").Do()
}

func (asc *adminServiceClient) ListMembers(groupKey string) (*admin.Members, error) {
	return asc.service.Members.List(groupKey).Do()
}

func (asc *adminServiceClient) InsertGroup(group *admin.Group) (*admin.Group, error) {
	return asc.service.Groups.Insert(group).Do()
}

func (asc *adminServiceClient) InsertMember(groupKey string, member *admin.Member) (*admin.Member, error) {
	return asc.service.Members.Insert(groupKey, member).Do()
}

func (asc *adminServiceClient) UpdateGroup(groupKey string, group *admin.Group) (*admin.Group, error) {
	return asc.service.Groups.Update(groupKey, group).Do()
}

func (asc *adminServiceClient) UpdateMember(groupKey, memberKey string, member *admin.Member) (*admin.Member, error) {
	return asc.service.Members.Update(groupKey, memberKey, member).Do()
}

func (asc *adminServiceClient) DeleteGroup(groupKey string) error {
	return asc.service.Groups.Delete(groupKey).Do()
}

func (asc *adminServiceClient) DeleteMember(groupKey, memberKey string) error {
	return asc.service.Members.Delete(groupKey, memberKey).Do()
}

var _ AdminServiceClient = (*adminServiceClient)(nil)

type GroupServiceClient interface {
	Get(groupUniqueID string) (*groupssettings.Groups, error)
	Patch(groupUniqueID string, groups *groupssettings.Groups) (*groupssettings.Groups, error)
}

func NewGroupServiceClient(ctx context.Context, clientOption option.ClientOption) (GroupServiceClient, error) {
	groupSvc, err := groupssettings.NewService(ctx, clientOption)
	if err != nil {
		return nil, err
	}

	return &groupServiceClient{service: groupSvc}, nil
}

type groupServiceClient struct {
	service *groupssettings.Service
}

func (gsc *groupServiceClient) Get(groupUniqueID string) (*groupssettings.Groups, error) {
	return gsc.service.Groups.Get(groupUniqueID).Do()
}

func (gsc *groupServiceClient) Patch(groupUniqueID string, groups *groupssettings.Groups) (*groupssettings.Groups, error) {
	return gsc.service.Groups.Patch(groupUniqueID, groups).Do()
}

var _ GroupServiceClient = (*groupServiceClient)(nil)
