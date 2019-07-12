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
	"crypto/tls"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"golang.org/x/net/context"
	"golang.org/x/oauth2/google"
	"google.golang.org/api/admin/directory/v1"
	"google.golang.org/api/googleapi"
	"google.golang.org/api/groupssettings/v1"
	"gopkg.in/yaml.v2"
)

type Config struct {
	// the email id for the bot/service account
	BotID string `yaml:"bot-id"`

	// the file with the authentication information
	TokenFile string `yaml:"token-file,omitempty"`

	// the file with the groups/members information
	GroupsFile string `yaml:"groups-file,omitempty"`

	// If false, don't make any mutating API calls
	ConfirmChanges bool
}

type GroupsConfig struct {
	// List of google groups
	Groups []GoogleGroup `yaml:"groups,omitempty"`
}

type GoogleGroup struct {
	EmailId     string `yaml:"email-id"`
	Description string `yaml:"description"`

	// List of members in the google group
	Members []string `yaml:"members,omitempty"`
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

func main() {
	configFilePath := flag.String("config", "config.yaml", "the config file in yaml format")
	confirmChanges := flag.Bool("confirm", false, "false by default means that we do not push anything to google groups")

	flag.Usage = Usage
	flag.Parse()

	err := readConfig(configFilePath, confirmChanges)
	if err != nil {
		log.Fatal(err)
	}

	err = readGroupsConfig(config.GroupsFile)
	if err != nil {
		log.Fatal(err)
	}

	jsonCredentials, err := ioutil.ReadFile(config.TokenFile)
	if err != nil {
		log.Fatal(err)
	}

	credential, err := google.JWTConfigFromJSON(jsonCredentials, admin.AdminDirectoryUserReadonlyScope,
		admin.AdminDirectoryGroupScope,
		admin.AdminDirectoryGroupMemberScope,
		groupssettings.AppsGroupsSettingsScope)
	if err != nil {
		log.Fatalf("Unable to parse client secret file to config: %v\n. "+
			"Please run 'git-crypt unlock'", err)
	}
	credential.Subject = config.BotID

	client := credential.Client(context.Background())
	srv, err := admin.New(client)
	if err != nil {
		log.Fatalf("Unable to retrieve directory Client %v", err)
	}

	srv2, err := groupssettings.New(client)
	if err != nil {
		log.Fatalf("Unable to retrieve groupssettings Service %v", err)
	}

	log.Println(" =================== Current Status ======================")
	err = printGroupMembersAndSettings(srv, srv2)
	if err != nil {
		log.Fatal(err)
	}

	log.Println(" ======================= Updates =========================")
	for _, g := range groupsConfig.Groups {
		if !strings.HasPrefix(g.EmailId, "k8s-infra-") {
			log.Fatalf("We can reconcile only groups that start with 'k8s-infra-' prefix")
		}
		err = createGroupIfNecessary(srv, g.EmailId, g.Description)
		if err != nil {
			log.Fatal(err)
		}
		err = updateGroupSettingsToAllowExternalMembers(srv2, g.EmailId)
		if err != nil {
			log.Fatal(err)
		}
		err = addMembersToGroup(srv, g.EmailId, g.Members)
		if err != nil {
			log.Fatal(err)
		}
		err = removeMembersFromGroup(srv, g.EmailId, g.Members)
		if err != nil {
			log.Fatal(err)
		}
	}
	err = deleteGroupsIfNecessary(srv)
	if err != nil {
		log.Fatal(err)
	}
}

func readConfig(configFilePath *string, confirmChanges *bool) error {
	content, err := ioutil.ReadFile(*configFilePath)
	if err != nil {
		return fmt.Errorf("error reading config from file: %v", err)
	}
	if err = yaml.Unmarshal(content, &config); err != nil {
		return fmt.Errorf("error reading config: %v", err)
	}
	if confirmChanges != nil {
		config.ConfirmChanges = *confirmChanges
	}
	return err
}

func readGroupsConfig(groupsConfigFilePath string) error {
	var content []byte
	var err error
	groupsUrl, err := url.ParseRequestURI(groupsConfigFilePath)
	if err == nil {
		// We have a URL, so try reading from it
		if len(groupsUrl.Host) > 0 {
			if content, err = readFromUrl(groupsUrl); err != nil {
				return fmt.Errorf("error reading groups config from file: %v", err)
			}
		}
	} else {
		// We don't have a URL, we have a file path, so try reading from the file
		if content, err = ioutil.ReadFile(groupsConfigFilePath); err != nil {
			return fmt.Errorf("error reading groups config from file: %v", err)
		}
	}
	if err = yaml.Unmarshal(content, &groupsConfig); err != nil {
		return fmt.Errorf("error reading groups config: %v", err)
	}
	return nil
}

// readFromUrl reads the rule file from provided URL.
func readFromUrl(u *url.URL) ([]byte, error) {
	client := &http.Client{Transport: &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}}
	req, err := http.NewRequest("GET", u.String(), nil)
	if err != nil {
		return nil, err
	}
	// timeout the request after 30 seconds
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	return ioutil.ReadAll(resp.Body)
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
	for _, g := range g.Groups {
		// Don't touch existing mailing lists, we should
		// always prefix with "k8s-infra-"
		if !strings.HasPrefix(g.Email, "k8s-infra-") {
			continue
		}
		log.Printf("%s\n", g.Email)

		g2, err := srv2.Groups.Get(g.Email).Do()
		if err != nil {
			return fmt.Errorf("unable to retrieve group info for group %s: %v", g.Email, err)
		}
		log.Printf(">> Allow external members %s\n", g2.AllowExternalMembers)

		l, err := srv.Members.List(g.Email).Do()
		if err != nil {
			return fmt.Errorf("unable to retrieve members in group : %v", err)
		}

		if len(l.Members) == 0 {
			log.Println("No members found in group.")
		} else {
			for _, m := range l.Members {
				log.Printf(">>> %s (%s)\n", m.Email, m.Role)
			}
		}
		log.Printf("\n")

	}
	return nil
}

func createGroupIfNecessary(srv *admin.Service, groupEmailId string, description string) error {
	_, err := srv.Groups.Get(groupEmailId).Do()
	if err != nil {
		if apierr, ok := err.(*googleapi.Error); ok && apierr.Code == http.StatusNotFound {
			if !config.ConfirmChanges {
				log.Printf("dry-run : skipping creation of group %s\n", groupEmailId)
			} else {
				log.Printf("Trying to create group: %s\n", groupEmailId)
				g4, err := srv.Groups.Insert(&admin.Group{
					Email:       groupEmailId,
					Name:        description,
					Description: "Kubernetes wg-k8s-infra test group #2",
				}).Do()
				if err != nil {
					return fmt.Errorf("unable to add new group %s: %v", groupEmailId, err)
				}
				log.Printf("> Successfully created group %s\n", g4.Email)
			}
		} else {
			return fmt.Errorf("unable to fetch group: %#v", err.Error())
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
		// Don't touch existing mailing lists, we should
		// always prefix with "k8s-infra-"
		if !strings.HasPrefix(g.Email, "k8s-infra-") {
			continue
		}
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

func updateGroupSettingsToAllowExternalMembers(srv *groupssettings.Service, groupEmailId string) error {
	g2, err := srv.Groups.Get(groupEmailId).Do()
	if err != nil {
		if apierr, ok := err.(*googleapi.Error); ok && apierr.Code == http.StatusNotFound {
			log.Printf("skipping updating group settings as group %s has not yet been created\n", groupEmailId)
			return nil
		}
		return fmt.Errorf("unable to retrieve group info for group %s: %v", groupEmailId, err)
	}

	settings := &groupssettings.Groups{
		AllowExternalMembers:  "true",
		WhoCanJoin:            "INVITED_CAN_JOIN",
		WhoCanViewMembership:  "ALL_MEMBERS_CAN_VIEW",
		WhoCanViewGroup:       "ALL_MEMBERS_CAN_VIEW",
		WhoCanInvite:          "ALL_MANAGERS_CAN_INVITE",
		WhoCanAdd:             "ALL_MANAGERS_CAN_ADD",
		WhoCanApproveMembers:  "ALL_MANAGERS_CAN_APPROVE",
		WhoCanModifyMembers:   "OWNERS_ONLY",
		WhoCanModerateMembers: "OWNERS_ONLY",
		WhoCanDiscoverGroup:   "ALL_MEMBERS_CAN_DISCOVER",
	}

	if g2.AllowExternalMembers != settings.AllowExternalMembers ||
		g2.WhoCanJoin != settings.WhoCanJoin ||
		g2.WhoCanViewMembership != settings.WhoCanViewMembership ||
		g2.WhoCanViewGroup != settings.WhoCanViewGroup ||
		g2.WhoCanInvite != settings.WhoCanInvite ||
		g2.WhoCanAdd != settings.WhoCanAdd ||
		g2.WhoCanApproveMembers != settings.WhoCanApproveManagers ||
		g2.WhoCanModifyMembers != settings.WhoCanModifiyMembers ||
		g2.WhoCanModerateMembers != settings.WhoCanModerateMembers ||
		g2.WhoCanDiscoverGroup != settings.WhoCanDiscoverGroup {

		if config.ConfirmChanges {
			_, err := srv.Groups.Patch(groupEmailId, settings).Do()
			if err != nil {
				return fmt.Errorf("unable to update group info for group %s: %v", groupEmailId, err)
			}
			log.Printf("> Successfully updated group settings for %s to allow external members and other security settings\n", groupEmailId)
		} else {
			log.Printf("dry-run : skipping updating group settings for %s\n", groupEmailId)
		}
	}
	return nil
}

func addMembersToGroup(service *admin.Service, groupEmailId string, members []string) error {
	l, err := service.Members.List(groupEmailId).Do()
	if err != nil {
		if apierr, ok := err.(*googleapi.Error); ok && apierr.Code == http.StatusNotFound {
			log.Printf("skipping adding members to group %s as it has not yet been created\n", groupEmailId)
			return nil
		}
		return fmt.Errorf("unable to retrieve members in group %s: %v", groupEmailId, err)
	}

	for _, m := range members {
		found := false
		for _, m2 := range l.Members {
			if m2.Email == m {
				found = true
				break
			}
		}
		if found {
			continue
		}
		// We did not find the person in the google group, so we add them
		if config.ConfirmChanges {
			_, err := service.Members.Insert(groupEmailId, &admin.Member{
				Email: m,
				Role:  "MEMBER",
			}).Do()
			if err != nil {
				return fmt.Errorf("unable to add %s to %s : %v", m, groupEmailId, err)
			}
			log.Printf("Added %s to %s as a MEMBER\n", m, groupEmailId)
		} else {
			log.Printf("dry-run : Skipping adding %s to %s\n", m, groupEmailId)
		}
	}
	return nil
}

func removeMembersFromGroup(service *admin.Service, groupEmailId string, members []string) error {
	l, err := service.Members.List(groupEmailId).Do()
	if err != nil {
		if apierr, ok := err.(*googleapi.Error); ok && apierr.Code == http.StatusNotFound {
			log.Printf("skipping removing members group %s as group has not yet been created\n", groupEmailId)
			return nil
		}
		return fmt.Errorf("unable to retrieve members in group %s: %v", groupEmailId, err)
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
			err := service.Members.Delete(groupEmailId, m.Email).Do()
			if err != nil {
				return fmt.Errorf("unable to remove %s from %s : %v", m.Email, groupEmailId, err)
			}
			log.Printf("Removing %s from %s as a MEMBER\n", m.Email, groupEmailId)
		} else {
			log.Printf("dry-run : Skipping removing %s from %s\n", m.Email, groupEmailId)
		}
	}
	return nil
}
