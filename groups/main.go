package main

import (
	"flag"
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
		Short: "GSuite Groups Reconciler, implemented with Go.",
		Run: func(cmd *cobra.Command, args []string) {
			// Print out help info if parent command is run.
			cmd.Help()
		},
	}

	validate := &cobra.Command{
		Use:   "validate",
		Short: "Checks the yaml files for illegal configurations",
		Run: func(cmd *cobra.Command, args []string) {
			groupsPath, _ := cmd.Flags().GetString("groups-path")
			restrictionsPath, _ := cmd.Flags().GetString("restrictions-path")
			configFile, _ := cmd.Flags().GetString("config")
			Validate(&configFile, &groupsPath, &restrictionsPath)
		},
	}

	plan := &cobra.Command{
		Use:   "plan",
		Short: "Prints a plan of proposed changes to Google Groups",
		Run: func(cmd *cobra.Command, args []string) {
			configFile, _ := cmd.Flags().GetString("config")
			Reconcile(false, configFile)
		},
	}

	apply := &cobra.Command{
		Use:   "apply",
		Short: "Reconciles the supplied configuration to Google Groups",
		Run: func(cmd *cobra.Command, args []string) {
			configFile, _ := cmd.Flags().GetString("config")
			Reconcile(true, configFile)
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

func Reconcile(confirmChanges bool, configFilePath string) {
	err := config.Load(configFilePath, confirmChanges)
	if err != nil {
		log.Fatal(err)
	}

	PrintConfig(config)
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

	r, err := NewReconciler(ctx, clientOption)
	if err != nil {
		log.Fatal(err)
	}

	log.Println(" ======================= Updates =======================")
	err = r.ReconcileGroups(groupsConfig.Groups)
	if err != nil {
		log.Fatal(err)
	}
}
