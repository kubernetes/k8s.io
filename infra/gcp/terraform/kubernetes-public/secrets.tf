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

locals {
  aaa_apps = {
    elekto = {
      group = "sig-contributor-experience"
      secrets = [
        "elekto-db-database",
        "elekto-db-host",
        "elekto-db-password",
        "elekto-db-port",
        "elekto-db-username",
        "elekto-github-client-id",
        "elekto-github-client-secret",
        "elekto-meta-secret",
      ]
    },
    prow = {
      group = "sig-testing"
      secrets = [
        "k8s-infra-build-clusters-kubeconfig",
        "k8s-infra-cherrypick-robot-github-token",
        "k8s-infra-ci-robot-github-account-password",
        "k8s-infra-ci-robot-github-token",
        "k8s-infra-prow-cookie",
        "k8s-infra-prow-github-oauth-config",
        "k8s-infra-prow-hmac-token",
      ]
    },
    publishing-bot = {
      group = "sig-release"
      secrets = [
        "publishing-bot-github-token",
      ]
    },
    slack-infra = {
      group = "sig-contributor-experience"
      secrets = [
        "recaptcha-secret-key",
        "recaptcha-site-key",
        "slack-event-log-config",
        "slack-moderator-config",
        "slack-moderator-words-config",
        "slack-post-message-config",
        "slack-welcomer-config",
        "slackin-token",
      ]
    },
  }
  // Even though we could just use the list, we're going to keep parity with
  // the map structure used in k8s-infra-prow-build, so resource definitions
  // look similar
  aaa_app_secrets = {
    for s in flatten([
      for app_name, app in local.aaa_apps : [
        for secret in app.secrets : {
          app = app_name
          group = app.group
          owners = "k8s-infra-rbac-${app_name}@kubernetes.io"
          secret = secret
        }
      ]
    ]) : s.secret => s
  }
}

resource "google_secret_manager_secret" "aaa_app_secrets" {
  for_each  = local.aaa_app_secrets
  project   = data.google_project.project.project_id
  secret_id = each.key
  labels = {
    app = each.value.app
    group = each.value.group
  }
  replication {
    automatic = true
  }
}


resource "google_secret_manager_secret_iam_binding" "aaa_app_secret_admins" {
  for_each  = local.aaa_app_secrets
  project   = google_secret_manager_secret.aaa_app_secrets[each.key].project
  secret_id = google_secret_manager_secret.aaa_app_secrets[each.key].id
  role      = "roles/secretmanager.admin"
  members = [
    "group:${each.value.owners}"
  ]
}
