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
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"

	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
	"github.com/bmatcuk/doublestar"
	"golang.org/x/net/context"
	"golang.org/x/oauth2/google"
	admin "google.golang.org/api/admin/directory/v1"
	"google.golang.org/api/groupssettings/v1"
	"google.golang.org/api/option"
	"gopkg.in/yaml.v3"

	utilerrors "k8s.io/apimachinery/pkg/util/errors"
	"sigs.k8s.io/prow/pkg/genyaml"
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
	GroupsPath string `yaml:"groups-path,omitempty"`

	// RestrictionsPath is the absolute path to the configuration file
	// containing restrictions for which groups can be defined in sub-directories.
	// If not specified, it defaults to "restrictions.yaml" in the groups-path directory.
	RestrictionsPath string `yaml:"restrictions-path,omitempty"`

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

// RestrictionsConfig contains the list of restrictions for
// which groups can be defined in sub-directories.
type RestrictionsConfig struct {
	Restrictions []Restriction `yaml:"restrictions,omitempty" json:"restrictions,omitempty"`
}

type Restriction struct {
	// Path is the relative path of a sub-directory to the groups-path.
	Path string `yaml:"path" json:"path"`
	// AllowedGroups is the list of regular expressions for email-ids
	// of groups that can be defined for the Path.
	//
	// Compiles to AllowedGroupsRe during config load.
	AllowedGroups []string `yaml:"allowedGroups" json:"allowedGroups"`

	AllowedGroupsRe []*regexp.Regexp
}

func Usage() {
	fmt.Fprintf(os.Stderr, `
Usage: %s [-config <config-yaml-file>] [--confirm]
Command line flags override config values.
`, os.Args[0])
	flag.PrintDefaults()
}

var (
	config             Config
	groupsConfig       GroupsConfig
	restrictionsConfig RestrictionsConfig

	verbose = flag.Bool("v", false, "log extra information")

	defaultConfigFile       = "config.yaml"
	defaultRestrictionsFile = "restrictions.yaml"
	emptyRegexp             = regexp.MustCompile("")
	defaultRestriction      = Restriction{Path: "*", AllowedGroupsRe: []*regexp.Regexp{emptyRegexp}}
	defaultNumWorkers       = 5
)

func main() {
	configFilePath := flag.String("config", defaultConfigFile, "the config file in yaml format")
	confirmChanges := flag.Bool("confirm", false, "false by default means that we do not push anything to google groups")
	printConfig := flag.Bool("print", false, "print the existing group information")
	numWorkers := flag.Int("workers", defaultNumWorkers, "number of concurrent workers to use")

	flag.Usage = Usage
	flag.Parse()

	if *printConfig {
		log.Printf("print: %v -- disabling confirm, will print existing group information", *confirmChanges)
		*confirmChanges = false
	}
	if !*confirmChanges {
		log.Printf("confirm: %v -- dry-run mode, changes will not be pushed", *confirmChanges)
	}
	if *numWorkers < 1 {
		*numWorkers = 1
	}
	log.Printf("workers: %v", *numWorkers)

	err := config.Load(*configFilePath, *confirmChanges)
	if err != nil {
		log.Fatal(err)
	}

	log.Printf("config: BotID:            %v", config.BotID)
	log.Printf("config: SecretVersion:    %v", config.SecretVersion)
	log.Printf("config: GroupsPath:       %v", config.GroupsPath)
	log.Printf("config: RestrictionsPath: %v", config.RestrictionsPath)
	log.Printf("config: ConfirmChanges:   %v", config.ConfirmChanges)

	err = restrictionsConfig.Load(config.RestrictionsPath)
	if err != nil {
		log.Fatal(err)
	}

	err = groupsConfig.Load(config.GroupsPath, &restrictionsConfig)
	if err != nil {
		log.Fatal(err)
	}

	serviceAccountKey, err := accessSecretVersion(config.SecretVersion)
	if err != nil {
		log.Fatalf("Unable to access secret-version %s, %v", config.SecretVersion, err)
	}

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

	r, err := NewReconciler(ctx, clientOption, *numWorkers)
	if err != nil {
		log.Fatal(err)
	}

	if *printConfig {
		err = r.printGroupMembersAndSettings()
		if err != nil {
			log.Fatal(err)
		}
		return
	}

	log.Println(" ======================= Updates =======================")
	err = r.ReconcileGroups(groupsConfig.Groups)
	if err != nil {
		log.Fatal(err)
	}
}

// Reconciler syncs the actual state of the world with the configuration.
// It does so by making use of AdminService and GroupService which are mockable
// interfaces.
type Reconciler struct {
	adminService AdminService
	groupService GroupService
	numWorkers   int
}

func NewReconciler(ctx context.Context, clientOption option.ClientOption, numWorkers int) (*Reconciler, error) {
	as, err := NewAdminService(ctx, clientOption)
	if err != nil {
		return nil, err
	}

	gs, err := NewGroupService(ctx, clientOption)
	if err != nil {
		return nil, err
	}

	return &Reconciler{adminService: as, groupService: gs, numWorkers: numWorkers}, nil
}

func (r *Reconciler) ReconcileGroups(groups []GoogleGroup) error {
	// aggregate the errors that occured and return them together in the end.
	var errs []error
	groupChan := make(chan GoogleGroup, len(groups))
	for _, g := range groups {
		groupChan <- g
	}
	close(groupChan)

	numWorkers := r.numWorkers
	if numWorkers < 1 {
		numWorkers = 1
	} else if numWorkers > len(groups) {
		numWorkers = len(groups)
	}
	wg := sync.WaitGroup{}
	wg.Add(numWorkers)
	errsChan := make(chan []error, len(groups))

	for i := 0; i < numWorkers; i++ {
		go func(groups <-chan GoogleGroup, n int) {
			defer wg.Done()
			var errs []error
			for g := range groups {
				if g.EmailId == "" {
					errs = append(errs, fmt.Errorf("group has no email-id: %#v", g))
				}

				err := r.adminService.CreateOrUpdateGroupIfNescessary(g)
				if err != nil {
					errs = append(errs, err)
				}

				err = r.groupService.UpdateGroupSettings(g)
				if err != nil {
					errs = append(errs, err)
				}

				err = r.adminService.AddOrUpdateGroupMembers(g, OwnerRole, g.Owners)
				if err != nil {
					errs = append(errs, err)
				}

				err = r.adminService.AddOrUpdateGroupMembers(g, ManagerRole, g.Managers)
				if err != nil {
					errs = append(errs, err)
				}

				err = r.adminService.AddOrUpdateGroupMembers(g, MemberRole, g.Members)
				if err != nil {
					errs = append(errs, err)
				}

				if g.Settings["ReconcileMembers"] == "true" {
					members := append(g.Owners, g.Managers...)
					members = append(members, g.Members...)
					err = r.adminService.RemoveMembersFromGroup(g, members)
					if err != nil {
						errs = append(errs, err)
					}
				} else {
					members := append(g.Owners, g.Managers...)
					err = r.adminService.RemoveOwnerOrManagersFromGroup(g, members)
					if err != nil {
						errs = append(errs, err)
					}
				}
			}
			errsChan <- errs
		}(groupChan, i)
	}
	wg.Wait()

	close(errsChan)

	for workerErrs := range errsChan {
		errs = append(errs, workerErrs...)
	}

	err := r.adminService.DeleteGroupsIfNecessary()
	if err != nil {
		errs = append(errs, err)
	}

	return utilerrors.NewAggregate(errs)
}

func (r *Reconciler) printGroupMembersAndSettings() error {
	g, err := r.adminService.ListGroups()
	if err != nil {
		return fmt.Errorf("unable to retrieve users in domain: %w", err)
	}

	var groupsConfig GroupsConfig
	for _, g := range g.Groups {
		group := GoogleGroup{
			EmailId:     g.Email,
			Name:        g.Name,
			Description: g.Description,
		}
		g2, err := r.groupService.Get(g.Email)
		if err != nil {
			return fmt.Errorf("unable to retrieve group info for group %s: %w", g.Email, err)
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

		l, err := r.adminService.ListMembers(g.Email)
		if err != nil {
			return fmt.Errorf("unable to retrieve members in group : %w", err)
		}

		for _, m := range l {
			switch m.Role {
			case OwnerRole:
				group.Owners = append(group.Owners, m.Email)
			case ManagerRole:
				group.Managers = append(group.Managers, m.Email)
			case MemberRole:
				group.Members = append(group.Members, m.Email)
			}
		}

		groupsConfig.Groups = append(groupsConfig.Groups, group)
	}

	cm, err := genyaml.NewCommentMap(nil, nil, "reconcile.go")
	if err != nil {
		return fmt.Errorf("failed to construct commentMap: %w", err)
	}
	yamlSnippet, err := cm.GenYaml(groupsConfig)
	if err != nil {
		return fmt.Errorf("unable to generate yaml for groups : %w", err)
	}

	fmt.Println(yamlSnippet)
	return nil
}

func (c *Config) Load(configFilePath string, confirmChanges bool) error {
	log.Printf("reading config file: %s", configFilePath)
	content, err := os.ReadFile(configFilePath)
	if err != nil {
		return fmt.Errorf("error reading config file %s: %w", configFilePath, err)
	}
	if err = yaml.Unmarshal(content, &c); err != nil {
		return fmt.Errorf("error parsing config file %s: %w", configFilePath, err)
	}

	if !filepath.IsAbs(c.GroupsPath) {
		c.GroupsPath = filepath.Clean(filepath.Join(filepath.Dir(configFilePath), c.GroupsPath))
	}
	c.GroupsPath, err = filepath.Abs(c.GroupsPath)
	if err != nil {
		return fmt.Errorf("error converting groups-path %v to absolute path: %w", c.GroupsPath, err)
	}

	if c.RestrictionsPath == "" {
		c.RestrictionsPath = filepath.Join(filepath.Dir(configFilePath), defaultRestrictionsFile)
	}
	c.RestrictionsPath, err = filepath.Abs(c.RestrictionsPath)
	if err != nil {
		return fmt.Errorf("error converting retrictions-path %v to absolute path: %w", c.RestrictionsPath, err)
	}

	c.ConfirmChanges = confirmChanges
	return err
}

// Load populates the RestrictionsConfig with data parsed from path and returns
// nil if successful, or an error otherwise
func (rc *RestrictionsConfig) Load(path string) error {
	log.Printf("reading restrictions config file: %s", path)
	content, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("error reading restrictions config file %s: %w", path, err)
	}
	if err = yaml.Unmarshal(content, &rc); err != nil {
		return fmt.Errorf("error parsing restrictions config file %s: %w", path, err)
	}

	ret := make([]Restriction, 0, len(rc.Restrictions))
	for _, r := range rc.Restrictions {
		r.AllowedGroupsRe = make([]*regexp.Regexp, 0, len(r.AllowedGroups))
		for _, g := range r.AllowedGroups {
			re, err := regexp.Compile(g)
			if err != nil {
				return fmt.Errorf("error parsing group pattern %q for path %q: %w", g, r.Path, err)
			}
			r.AllowedGroupsRe = append(r.AllowedGroupsRe, re)
		}
		ret = append(ret, r)
	}
	rc.Restrictions = ret
	return err
}

// readGroupsConfig starts at the rootDir and recursively walksthrough
// all directories and files. It reads the GroupsConfig from all groups.yaml
// files and verifies that the groups in GroupsConfig satisfy the
// restrictions in restrictionsConfig.
// Finally, it adds all the groups in each GroupsConfig to config.Groups.
func (gc *GroupsConfig) Load(rootDir string, restrictions *RestrictionsConfig) error {
	log.Printf("reading groups.yaml files recursively at %s", rootDir)

	return filepath.Walk(rootDir, func(path string, info os.FileInfo, _ error) error {
		if filepath.Base(path) == "groups.yaml" {
			cleanPath := strings.Trim(strings.TrimPrefix(path, rootDir), string(filepath.Separator))
			log.Printf("groups: %s", cleanPath)

			var (
				groupsConfigAtPath GroupsConfig
				content            []byte
				err                error
			)

			if content, err = os.ReadFile(path); err != nil {
				return fmt.Errorf("error reading groups config file %s: %w", path, err)
			}
			if err = yaml.Unmarshal(content, &groupsConfigAtPath); err != nil {
				return fmt.Errorf("error parsing groups config at %s: %w", path, err)
			}

			r := restrictions.GetRestrictionForPath(path, rootDir)
			mergedGroups, err := mergeGroups(gc.Groups, groupsConfigAtPath.Groups, r)
			if err != nil {
				return fmt.Errorf("couldn't merge groups: %w", err)
			}
			gc.Groups = mergedGroups
		}
		return nil
	})
}

// GetRestrictionForPath returns the first Restriction whose Path matches the
// given path relative to the given rootDir, or defaultRestriction if no
// Restriction is found
func (rc *RestrictionsConfig) GetRestrictionForPath(path, rootDir string) Restriction {
	cleanPath := strings.Trim(strings.TrimPrefix(path, rootDir), string(filepath.Separator))
	for _, r := range rc.Restrictions {
		if match, err := doublestar.Match(r.Path, cleanPath); err == nil && match {
			return r
		}
	}
	return defaultRestriction
}

func mergeGroups(a []GoogleGroup, b []GoogleGroup, r Restriction) ([]GoogleGroup, error) {
	emails := map[string]struct{}{}
	for _, v := range a {
		emails[v.EmailId] = struct{}{}
	}
	for _, v := range b {
		if v.EmailId == "" {
			return nil, fmt.Errorf("groups must have email-id")
		}
		if !matchesRegexList(v.EmailId, r.AllowedGroupsRe) {
			return nil, fmt.Errorf("cannot define group %q in %q", v.EmailId, r.Path)
		}
		if _, ok := emails[v.EmailId]; ok {
			return nil, fmt.Errorf("cannot overwrite group definitions (duplicate group name %s)", v.EmailId)
		}
	}
	return append(a, b...), nil
}

func matchesRegexList(s string, list []*regexp.Regexp) bool {
	for _, r := range list {
		if r.MatchString(s) {
			return true
		}
	}
	return false
}

// accessSecretVersion accesses the payload for the given secret version if one exists
// secretVersion is of the form projects/{project}/secrets/{secret}/versions/{version}
func accessSecretVersion(secretVersion string) ([]byte, error) {
	ctx := context.Background()
	client, err := secretmanager.NewClient(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to create secretmanager client: %w", err)
	}

	req := &secretmanagerpb.AccessSecretVersionRequest{
		Name: secretVersion,
	}

	result, err := client.AccessSecretVersion(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to access secret version: %w", err)
	}

	return result.Payload.Data, nil
}
