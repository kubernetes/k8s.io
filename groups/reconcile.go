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
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"reflect"

	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"golang.org/x/net/context"
	"golang.org/x/oauth2/google"
	admin "google.golang.org/api/admin/directory/v1"
	"google.golang.org/api/googleapi"
	"google.golang.org/api/groupssettings/v1"
	"google.golang.org/api/option"
	secretmanagerpb "google.golang.org/genproto/googleapis/cloud/secretmanager/v1"
	"gopkg.in/yaml.v2"

	"k8s.io/test-infra/pkg/genyaml"
)

type Config struct {
	// the email id for the bot/service account
	BotID string `yaml:"bot-id"`

	// the gcloud secret containing a service account key to authenticate with
	SecretVersion string `yaml:"secret-version,omitempty"`

	// GroupsPath is the path to the directory with
	// groups.yaml files containing groups/members information.
	// It must be an absolute path. If not specified,
	// it defaults to the directory containing the config.yaml file.
	GroupsPath *string `yaml:"groups-path,omitempty"`

	// If false, don't make any mutating API calls
	ConfirmChanges bool
}

type GroupsConfig struct {
	// This file has the list of groups in kubernetes.io gsuite org that we use
	// for granting permissions to various community resources.
	Groups []GoogleGroup `yaml:"groups,omitempty" json:"groups,omitempty"`
}

type GoogleGroup struct {
	EmailId     string `yaml:"email-id" json:"email-id"`
	Name        string `yaml:"name" json:"name"`
	Description string `yaml:"description" json:"description"`

	Settings map[string]string `yaml:"settings,omitempty" json:"settings,omitempty"`

	// +optional
	Owners []string `yaml:"owners,omitempty" json:"owners,omitempty"`

	// +optional
	Managers []string `yaml:"managers,omitempty" json:"managers,omitempty"`

	// +optional
	Members []string `yaml:"members,omitempty" json:"members,omitempty"`
}

func Usage() {
	fmt.Fprintf(os.Stderr, `
Usage: %s [-config <config-yaml-file>] [--confirm]
Command line flags override config values.
`, os.Args[0])
	flag.PrintDefaults()
}

var config Config
var groupsConfig GroupsConfig

var verbose = flag.Bool("v", false, "log extra information")

func main() {
	configFilePath := flag.String("config", "config.yaml", "the config file in yaml format")
	confirmChanges := flag.Bool("confirm", false, "false by default means that we do not push anything to google groups")
	printConfig := flag.Bool("print", false, "print the existing group information")

	flag.Usage = Usage
	flag.Parse()

	err := readConfig(*configFilePath, *confirmChanges)
	if err != nil {
		log.Fatal(err)
	}

	// rootDir contains groups.yaml files
	rootDir := filepath.Dir(*configFilePath)
	if config.GroupsPath != nil {
		if !filepath.IsAbs(*config.GroupsPath) {
			log.Fatalf("groups-path \"%s\" must be an absolute path", *config.GroupsPath)
		}
		rootDir = *config.GroupsPath
	}

	err = readGroupsConfig(rootDir, &groupsConfig)
	if err != nil {
		log.Fatal(err)
	}

	serviceAccountKey, err := accessSecretVersion(config.SecretVersion)

	credential, err := google.JWTConfigFromJSON(serviceAccountKey, admin.AdminDirectoryUserReadonlyScope,
		admin.AdminDirectoryGroupScope,
		admin.AdminDirectoryGroupMemberScope,
		groupssettings.AppsGroupsSettingsScope)
	if err != nil {
		log.Fatalf("Unable to authenticate using key in secret-version %s, %v", config.SecretVersion, err)
	}
	credential.Subject = config.BotID

	ctx := context.Background()
	client := credential.Client(ctx)
	clientOption := option.WithHTTPClient(client)

	srv, err := admin.NewService(ctx, clientOption)
	if err != nil {
		log.Fatalf("Unable to retrieve directory Client %v", err)
	}

	srv2, err := groupssettings.NewService(ctx, clientOption)
	if err != nil {
		log.Fatalf("Unable to retrieve groupssettings Service %v", err)
	}

	if *printConfig {
		err = printGroupMembersAndSettings(srv, srv2)
		if err != nil {
			log.Fatal(err)
		}
		return
	}

	log.Println(" ======================= Updates =========================")
	for _, g := range groupsConfig.Groups {
		if g.EmailId == "" {
			log.Fatal(fmt.Sprintf("Group has no email-id: %#v", g))
		}

		err = createOrUpdateGroupIfNecessary(srv, g.EmailId, g.Name, g.Description)
		if err != nil {
			log.Fatal(err)
		}
		err = updateGroupSettings(srv2, g.EmailId, g.Settings)
		if err != nil {
			log.Fatal(err)
		}
		err = addOrUpdateMemberToGroup(srv, g.EmailId, g.Owners, "OWNER")
		if err != nil {
			log.Fatal(err)
		}
		err = addOrUpdateMemberToGroup(srv, g.EmailId, g.Managers, "MANAGER")
		if err != nil {
			log.Fatal(err)
		}
		err = addOrUpdateMemberToGroup(srv, g.EmailId, g.Members, "MEMBER")
		if err != nil {
			log.Println(err)
		}
		if g.Settings["ReconcileMembers"] == "true" {
			members := append(g.Owners, g.Managers...)
			members = append(members, g.Members...)
			err = removeMembersFromGroup(srv, g.EmailId, members)
			if err != nil {
				log.Fatal(err)
			}
		} else {
			members := append(g.Owners, g.Managers...)
			err = removeOwnerOrManagersGroup(srv, g.EmailId, members)
			if err != nil {
				log.Fatal(err)
			}
		}
	}
	err = deleteGroupsIfNecessary(srv)
	if err != nil {
		log.Fatal(err)
	}
}

func readConfig(configFilePath string, confirmChanges bool) error {
	if *verbose {
		log.Printf("reading config file %s", configFilePath)
	}
	content, err := ioutil.ReadFile(configFilePath)
	if err != nil {
		return fmt.Errorf("error reading config file %s: %v", configFilePath, err)
	}
	if err = yaml.Unmarshal(content, &config); err != nil {
		return fmt.Errorf("error parsing config file %s: %v", configFilePath, err)
	}
	config.ConfirmChanges = confirmChanges
	return err
}

// readGroupsConfig starts at the rootDir and recursively walksthrough
// all directories and files. It reads the GroupsConfig from all groups.yaml
// files and adds the groups in each GroupsConfig to config.Groups.
func readGroupsConfig(rootDir string, config *GroupsConfig) error {
	if *verbose {
		log.Printf("reading groups.yaml files recursively at %s", rootDir)
	}

	return filepath.Walk(rootDir, func(path string, info os.FileInfo, err error) error {
		if filepath.Base(path) == "groups.yaml" {
			if *verbose {
				log.Printf("reading group file %s", path)
			}

			var groupsConfigAtPath GroupsConfig
			var content []byte

			if content, err = ioutil.ReadFile(path); err != nil {
				return fmt.Errorf("error reading groups config file %s: %v", path, err)
			}
			if err = yaml.Unmarshal(content, &groupsConfigAtPath); err != nil {
				return fmt.Errorf("error parsing groups config at %s: %v", path, err)
			}

			for _, g := range groupsConfigAtPath.Groups {
				config.Groups = append(config.Groups, g)
			}
		}
		return nil
	})
}

func printGroupMembersAndSettings(srv *admin.Service, srv2 *groupssettings.Service) error {
	g, err := srv.Groups.List().Customer("my_customer").OrderBy("email").Do()
	if err != nil {
		return fmt.Errorf("unable to retrieve users in domain: %v", err)
	}
	if len(g.Groups) == 0 {
		log.Println("No groups found.")
		return nil
	}
	var groupsConfig GroupsConfig
	for _, g := range g.Groups {
		group := GoogleGroup{
			EmailId:     g.Email,
			Name:        g.Name,
			Description: g.Description,
		}
		g2, err := srv2.Groups.Get(g.Email).Do()
		if err != nil {
			return fmt.Errorf("unable to retrieve group info for group %s: %v", g.Email, err)
		}
		group.Settings = make(map[string]string)
		group.Settings["AllowExternalMembers"] = g2.AllowExternalMembers
		group.Settings["WhoCanJoin"] = g2.WhoCanJoin
		group.Settings["WhoCanViewMembership"] = g2.WhoCanViewMembership
		group.Settings["WhoCanViewGroup"] = g2.WhoCanViewGroup
		group.Settings["WhoCanDiscoverGroup"] = g2.WhoCanDiscoverGroup
		group.Settings["WhoCanInvite"] = g2.WhoCanInvite
		group.Settings["WhoCanAdd"] = g2.WhoCanAdd
		group.Settings["WhoCanApproveMembers"] = g2.WhoCanApproveMembers
		group.Settings["WhoCanModifyMembers"] = g2.WhoCanModifyMembers
		group.Settings["WhoCanModerateMembers"] = g2.WhoCanModerateMembers
		group.Settings["MembersCanPostAsTheGroup"] = g2.MembersCanPostAsTheGroup

		l, err := srv.Members.List(g.Email).Do()
		if err != nil {
			return fmt.Errorf("unable to retrieve members in group : %v", err)
		}

		if len(l.Members) == 0 {
			log.Println("No members found in group.")
		} else {
			for _, m := range l.Members {
				if m.Role == "OWNER" {
					group.Owners = append(group.Owners, m.Email)
				}
			}
			for _, m := range l.Members {
				if m.Role == "MANAGER" {
					group.Managers = append(group.Managers, m.Email)
				}
			}
			for _, m := range l.Members {
				if m.Role == "MEMBER" {
					group.Members = append(group.Members, m.Email)
				}
			}
		}

		groupsConfig.Groups = append(groupsConfig.Groups, group)
	}

	cm := genyaml.NewCommentMap("reconcile.go")
	yamlSnippet, err := cm.GenYaml(groupsConfig)
	if err != nil {
		return fmt.Errorf("unable to generate yaml for groups : %v", err)
	}
	fmt.Println(yamlSnippet)
	return nil
}

func createOrUpdateGroupIfNecessary(srv *admin.Service, groupEmailId string, name string, description string) error {
	if *verbose {
		log.Printf("createOrUpdateGroupIfNecessary %q", groupEmailId)
	}
	group, err := srv.Groups.Get(groupEmailId).Do()
	if err != nil {
		if apierr, ok := err.(*googleapi.Error); ok && apierr.Code == http.StatusNotFound {
			if !config.ConfirmChanges {
				log.Printf("dry-run : skipping creation of group %q\n", groupEmailId)
			} else {
				log.Printf("Trying to create group: %q\n", groupEmailId)
				g := admin.Group{
					Email: groupEmailId,
				}
				if name != "" {
					g.Name = name
				}
				if description != "" {
					g.Description = description
				}
				g4, err := srv.Groups.Insert(&g).Do()
				if err != nil {
					return fmt.Errorf("unable to add new group %q: %v", groupEmailId, err)
				}
				log.Printf("> Successfully created group %s\n", g4.Email)
			}
		} else {
			return fmt.Errorf("unable to fetch group %q: %#v", groupEmailId, err.Error())
		}
	} else {
		if name != "" && group.Name != name ||
			description != "" && group.Description != description {
			if !config.ConfirmChanges {
				log.Printf("dry-run : skipping update of group name/description %q\n", groupEmailId)
			} else {
				log.Printf("Trying to update group: %q\n", groupEmailId)
				g := admin.Group{
					Email: groupEmailId,
				}
				if name != "" {
					g.Name = name
				}
				if description != "" {
					g.Description = description
				}
				g4, err := srv.Groups.Update(groupEmailId, &g).Do()
				if err != nil {
					return fmt.Errorf("unable to update group %q: %v", groupEmailId, err)
				}
				log.Printf("> Successfully updated group %s\n", g4.Email)
			}
		}
	}
	return nil
}

func deleteGroupsIfNecessary(service *admin.Service) error {
	g, err := service.Groups.List().Customer("my_customer").OrderBy("email").Do()
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
			err := service.Groups.Delete(g.Email).Do()
			if err != nil {
				return fmt.Errorf("unable to remove group %s : %v", g.Email, err)
			}
			log.Printf("Removing group %s\n", g.Email)
		} else {
			log.Printf("dry-run : Skipping removing group %s\n", g.Email)
		}

	}
	return nil
}

func updateGroupSettings(srv *groupssettings.Service, groupEmailId string, groupSettings map[string]string) error {
	if *verbose {
		log.Printf("updateGroupSettings %q", groupEmailId)
	}
	g2, err := srv.Groups.Get(groupEmailId).Do()
	if err != nil {
		if apierr, ok := err.(*googleapi.Error); ok && apierr.Code == http.StatusNotFound {
			log.Printf("skipping updating group settings as group %q has not yet been created\n", groupEmailId)
			return nil
		}
		return fmt.Errorf("unable to retrieve group info for group %q: %v", groupEmailId, err)
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

	for key, value := range groupSettings {
		switch key {
		case "AllowExternalMembers":
			wantSettings.AllowExternalMembers = value
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
			_, err := srv.Groups.Patch(groupEmailId, &wantSettings).Do()
			if err != nil {
				return fmt.Errorf("unable to update group info for group %q: %v", groupEmailId, err)
			}
			log.Printf("> Successfully updated group settings for %q to allow external members and other security settings\n", groupEmailId)
		} else {
			log.Printf("dry-run : skipping updating group settings for %q\n", groupEmailId)
			log.Printf("dry-run : current settings %+q", haveSettings)
			log.Printf("dry-run : desired settings %+q", wantSettings)
		}
	}
	return nil
}

func addOrUpdateMemberToGroup(service *admin.Service, groupEmailId string, members []string, role string) error {
	if *verbose {
		log.Printf("addOrUpdateMemberToGroup %s %q %v", role, groupEmailId, members)
	}
	l, err := service.Members.List(groupEmailId).Do()
	if err != nil {
		if apierr, ok := err.(*googleapi.Error); ok && apierr.Code == http.StatusNotFound {
			log.Printf("skipping adding members to group %q as it has not yet been created\n", groupEmailId)
			return nil
		}
		return fmt.Errorf("unable to retrieve members in group %q: %v", groupEmailId, err)
	}
	for _, m := range members {
		found := false
		currentRole := ""
		for _, m2 := range l.Members {
			if m2.Email == m {
				found = true
				currentRole = m2.Role
				break
			}
		}
		if found {
			if currentRole != "" && currentRole != role {
				// We did not find the person in the google group, so we add them
				if config.ConfirmChanges {
					_, err := service.Members.Update(groupEmailId, m, &admin.Member{
						Role: role,
					}).Do()
					if err != nil {
						return fmt.Errorf("unable to update %s to %q as %s : %v", m, groupEmailId, role, err)
					}
					log.Printf("Updated %s to %q as a %s\n", m, groupEmailId, role)
				} else {
					log.Printf("dry-run : Skipping updating %s to %q as %s\n", m, groupEmailId, role)
				}
			}
			continue
		}
		// We did not find the person in the google group, so we add them
		if config.ConfirmChanges {
			_, err := service.Members.Insert(groupEmailId, &admin.Member{
				Email: m,
				Role:  role,
			}).Do()
			if err != nil {
				return fmt.Errorf("unable to add %s to %q as %s : %v", m, groupEmailId, role, err)
			}
			log.Printf("Added %s to %q as a %s\n", m, groupEmailId, role)
		} else {
			log.Printf("dry-run : Skipping adding %s to %q as %s\n", m, groupEmailId, role)
		}
	}
	return nil
}

func removeOwnerOrManagersGroup(service *admin.Service, groupEmailId string, members []string) error {
	if *verbose {
		log.Printf("removeOwnerOrManagersGroup %q %v", groupEmailId, members)
	}
	l, err := service.Members.List(groupEmailId).Do()
	if err != nil {
		if apierr, ok := err.(*googleapi.Error); ok && apierr.Code == http.StatusNotFound {
			log.Printf("skipping removing members group %q as group has not yet been created\n", groupEmailId)
			return nil
		}
		return fmt.Errorf("unable to retrieve members in group %q: %v", groupEmailId, err)
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
			err := service.Members.Delete(groupEmailId, m.Id).Do()
			if err != nil {
				return fmt.Errorf("unable to remove %s from %q as OWNER or MANAGER : %v", m.Email, groupEmailId, err)
			}
			log.Printf("Removing %s from %q as OWNER or MANAGER\n", m.Email, groupEmailId)
		} else {
			log.Printf("dry-run : Skipping removing %s from %q as OWNER or MANAGER\n", m.Email, groupEmailId)
		}
	}
	return nil
}

func removeMembersFromGroup(service *admin.Service, groupEmailId string, members []string) error {
	if *verbose {
		log.Printf("removeMembersFromGroup %q %v", groupEmailId, members)
	}
	l, err := service.Members.List(groupEmailId).Do()
	if err != nil {
		if apierr, ok := err.(*googleapi.Error); ok && apierr.Code == http.StatusNotFound {
			log.Printf("skipping removing members group %q as group has not yet been created\n", groupEmailId)
			return nil
		}
		return fmt.Errorf("unable to retrieve members in group %q: %v", groupEmailId, err)
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
			err := service.Members.Delete(groupEmailId, m.Id).Do()
			if err != nil {
				return fmt.Errorf("unable to remove %s from %q as a %s : %v", m.Email, groupEmailId, m.Role, err)
			}
			log.Printf("Removing %s from %q as a %s\n", m.Email, groupEmailId, m.Role)
		} else {
			log.Printf("dry-run : Skipping removing %s from %q as a %s\n", m.Email, groupEmailId, m.Role)
		}
	}
	return nil
}

// DeepCopy deepcopies a to b using json marshaling. This discards fields like
// the server response that don't have a specifc json field name.
func deepCopySettings(a, b interface{}) {
	byt, _ := json.Marshal(a)
	json.Unmarshal(byt, b)
}

// accessSecretVersion accesses the payload for the given secret version if one exists
// secretVersion is of the form projects/{project}/secrets/{secret}/versions/{version}
func accessSecretVersion(secretVersion string) ([]byte, error) {
	ctx := context.Background()
	client, err := secretmanager.NewClient(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to create secretmanager client: %v", err)
	}

	req := &secretmanagerpb.AccessSecretVersionRequest{
		Name: secretVersion,
	}

	result, err := client.AccessSecretVersion(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to access secret version: %v", err)
	}

	return result.Payload.Data, nil
}
