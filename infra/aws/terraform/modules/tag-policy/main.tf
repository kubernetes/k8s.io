/*
Copyright 2023 The Kubernetes Authors.

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
  resource_actions = {
    ec2 = {
      type = "regional"
      scp  = true
      resources = {
        instance = {
          create_actions = [
            "RunInstances"
          ],
          delete_actions = [
            "DeleteTags"
          ]
        }
        volume = {
          create_actions = [
            "CreateVolume",
            "RunInstances"
          ],
          delete_actions = [
            "DeleteTags"
          ]
        },
        vpc = {
          create_actions = [
            "CreateVpc"
          ],
          delete_actions = [
            "DeleteTags"
          ]
        }
      }
    },
    eks = {
      type = "regional"
      scp  = true
      resources = {
        cluster = {
          create_actions = [
            "CreateCluster"
          ],
          delete_actions = [
            "UntagResource"
          ]
        }
      }
    },
    ecr = {
      type = "regional"
      scp  = true
      resources = {
        repository = {
          create_actions = [
            "CreateRepository"
          ],
          delete_actions = [
            "UntagResource",
          ]
        }
      }
    },
    s3 = {
      type = "global"
      scp  = false
      resources = {
        bucket = {
          create_actions = [],
          delete_actions = []
        }
      }
    }
  }

  # Filter selected services for tag enforcement
  selected_services = { for key in var.enforce_services : key => lookup(local.resource_actions, key) }

  # Create Tag policy from selected services
  selected_services_tag_policy = flatten([
    for service, config in local.selected_services : [
      for resource, actions in config.resources : [
        replace("${service}:${resource}", "all-resources", "*")
      ]
    ]
  ])

  tag_policy = {
    "tags" : {
      "${var.tag_name}" : {
        "tag_key" : {
          "@@assign" : var.tag_name
        },
        "tag_value" : {
          "@@assign" : var.tag_values
        },
        "enforced_for" : {
          "@@assign" : local.selected_services_tag_policy
        }
      }
    }
  }

  # ARN type config map for SCPs
  arn_type = {
    global   = ":::",
    account  = "::*:",
    regional = ":*:*:"
  }

  # Create list of actions for service request tag SCP
  create_tag_actions = flatten([
    for service, config in local.selected_services : [
      for resource, actions in config.resources : [
        for action in actions.create_actions : [
          "${service}:${action}"
        ]
      ] if config.scp
    ]
  ])

  # Create list of resources for service request tag SCP
  create_tag_resources = flatten([
    for service, config in local.selected_services : [
      for resource, actions in config.resources : [
        replace("arn:aws:${service}${lookup(local.arn_type, config.type)}${resource}/*", "all-resources", "*")
      ] if config.scp
    ]
  ])

  # Create list of actions for service deny tag deletion SCP
  delete_tag_actions = flatten([
    for service, config in local.selected_services : [
      for resource, actions in config.resources : [
        for action in actions.delete_actions : [
          "${service}:${action}"
        ]
      ] if config.scp
    ]
  ])

  # Create list of resources for service deny tag deletion SCP
  delete_tag_resources = flatten([
    for service, config in local.selected_services : [
      for resource, actions in config.resources : [
        replace("arn:aws:${service}${lookup(local.arn_type, config.type)}${resource}/*", "all-resources", "*")
      ] if config.scp
    ]
  ])
}

# ---------------------------- #
# Tag Policy
# ---------------------------- #

resource "aws_organizations_policy" "this" {
  name    = var.tag_name
  type    = "TAG_POLICY"
  content = jsonencode(local.tag_policy)
}


output "name" {
  value = local.selected_services
}

# --------------------------------- #
# Request tag Service Control Policy
# --------------------------------- #

data "aws_iam_policy_document" "request_tag" {
  statement {
    sid       = "RequestTag"
    effect    = "Deny"
    actions   = local.create_tag_actions
    resources = local.create_tag_resources

    condition {
      test     = "Null"
      variable = "aws:RequestTag/${var.tag_name}"
      values   = ["true"]
    }
  }
}

resource "aws_organizations_policy" "request_tag" {
  name        = "request-tag-${var.tag_name}"
  description = "Request tag ${var.tag_name} Service Control Policy"
  content     = data.aws_iam_policy_document.request_tag.json
}

# --------------------------------------- #
# Deny tag deletion Service Control Policy
# --------------------------------------- #

data "aws_iam_policy_document" "deny_tag_deletion" {
  statement {
    sid       = "DenyDeleteTag"
    effect    = "Deny"
    actions   = local.delete_tag_actions
    resources = local.delete_tag_resources

    condition {
      test     = "Null"
      variable = "aws:RequestTag/${var.tag_name}"
      values   = ["false"]
    }
  }
}

resource "aws_organizations_policy" "deny_tag_deletion" {
  name        = "deny-tag-deletion-${var.tag_name}"
  description = "Deny tag deletion ${var.tag_name} Service Control Policy"
  content     = data.aws_iam_policy_document.deny_tag_deletion.json
}

# --------------------------------------- #
# Enable Cost Allocation
# --------------------------------------- #

resource "aws_ce_cost_allocation_tag" "this" {
  count   = var.enable_cost_allocation ? 1 : 0
  tag_key = var.tag_name
  status  = "Active"
}
