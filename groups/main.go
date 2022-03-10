/*
Copyright 2022 The Kubernetes Authors.

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
	"regexp"

	"github.com/spf13/cobra"
	"golang.org/x/net/context"
	"golang.org/x/oauth2/google"
	admin "google.golang.org/api/admin/directory/v1"
	groupssettings "google.golang.org/api/groupssettings/v1"
	"google.golang.org/api/option"
)

var (
	config             Config
	groupsConfig       GroupsConfig
	restrictionsConfig RestrictionsConfig

	verbose = flag.Bool("v", false, "log extra information")

	defaultConfigFile       = "config.yaml"
	defaultRestrictionsFile = "restrictions.yaml"
	emptyRegexp             = regexp.MustCompile("")
	defaultRestriction      = Restriction{Path: "*", AllowedGroupsRe: []*regexp.Regexp{emptyRegexp}}
)

func main() {

	// Parent command to which all subcommands are added.
	rootCmd := &cobra.Command{
		Use:   "groups",
		Short: "GSuite Groups Reconciler, implemented in Go.",
		Run: func(cmd *cobra.Command, args []string) {
			// Print out help info if parent command is run.
			cmd.Help()
		},
	}

	validate := &cobra.Command{
		Use:   "validate",
		Short: "Checks the yaml files for illegal configurations",
		RunE: func(cmd *cobra.Command, args []string) error {
			groupsPath, _ := cmd.Flags().GetString("groups-path")
			restrictionsPath, _ := cmd.Flags().GetString("restrictions-path")
			configFile, _ := cmd.Flags().GetString("config")
			err := Validate(&configFile, &groupsPath, &restrictionsPath)
			if err != nil {
				return err
			}
			return nil
		},
	}

	plan := &cobra.Command{
		Use:   "plan",
		Short: "Prints a plan of proposed changes to Google Groups",
		RunE: func(cmd *cobra.Command, args []string) error {
			configFile, _ := cmd.Flags().GetString("config")
			err := Reconcile(false, configFile)
			if err != nil {
				return err
			}
			return nil
		},
	}

	apply := &cobra.Command{
		Use:   "apply",
		Short: "Reconciles the supplied configuration to Google Groups",
		RunE: func(cmd *cobra.Command, args []string) error {
			groupsPath, _ := cmd.Flags().GetString("groups-path")
			restrictionsPath, _ := cmd.Flags().GetString("restrictions-path")
			configFile, _ := cmd.Flags().GetString("config")
			err := Validate(&configFile, &groupsPath, &restrictionsPath)
			if err != nil {
				return err
			}
			err = Reconcile(false, configFile)
			if err != nil {
				return err
			}
			return nil
		},
	}
	rootCmd.PersistentFlags().String("config", "", "the config file in yaml format")
	rootCmd.PersistentFlags().String("groups-path", "", "Directory containing groups.yaml files")
	rootCmd.PersistentFlags().String("restrictions-path", "", "Path to the configuration file containing restrictions")
	rootCmd.AddCommand(validate)
	rootCmd.AddCommand(plan)
	rootCmd.AddCommand(apply)

	if err := rootCmd.Execute(); err != nil {
		log.Fatalf("Error during command execution: %v", err)
	}

}

func Reconcile(confirmChanges bool, configFilePath string) error {
	err := config.Load(configFilePath, confirmChanges)
	if err != nil {
		return err
	}

	PrintConfig(config)
	err = restrictionsConfig.Load(config.RestrictionsPath)
	if err != nil {
		return err
	}

	err = groupsConfig.Load(config.GroupsPath, &restrictionsConfig)
	if err != nil {
		return err
	}

	serviceAccountKey, err := accessSecretVersion(config.SecretVersion)
	if err != nil {
		return err
	}

	credential, err := google.JWTConfigFromJSON(serviceAccountKey, admin.AdminDirectoryUserReadonlyScope,
		admin.AdminDirectoryGroupScope,
		admin.AdminDirectoryGroupMemberScope,
		groupssettings.AppsGroupsSettingsScope)
	if err != nil {
		return fmt.Errorf("unable to authenticate using key in secret-version %s, %v", config.SecretVersion, err)
	}
	credential.Subject = config.BotID

	ctx := context.Background()

	r, err := NewReconciler(ctx, option.WithHTTPClient(credential.Client(ctx)))
	if err != nil {
		return err
	}

	log.Println(" ======================= Updates =======================")
	err = r.ReconcileGroups(groupsConfig.Groups)
	if err != nil {
		return err
	}
	return nil
}
