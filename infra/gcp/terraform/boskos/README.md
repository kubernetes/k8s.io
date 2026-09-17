# Boskos Terraform Module

This terraform directory defines the configuration of all the boskos projects.


This directory creates and manages 160+ GCP projects used by Boskos for ephemeral end-to-end test isolation.

## What This Manages

- `Boskos` **GCP folder** : This is under the `kubernetes.io` organization.
- **E2E projects**: Manages GCP projects used for several E2E tests.
- **Artifact Registry**: Used in each project (Docker format, 7-day cleanup, public read)
- **SSH keys**: Used for accessing Prow on each project's compute metadata.

## Project Configuration

Each Boskos project gets the following APIs enabled:

- `artifactregistry.googleapis.com`
- `cloudbuild.googleapis.com`
- `cloudkms.googleapis.com`
- `cloudresourcemanager.googleapis.com`
- `cloudscheduler.googleapis.com`
- `compute.googleapis.com`
- `container.googleapis.com`
- `file.googleapis.com`
- `logging.googleapis.com`
- `monitoring.googleapis.com`
- `secretmanager.googleapis.com`
- `cloudasset.googleapis.com`


## Terraform Documentation

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | 1.10.5 |
| <a name="requirement_google"></a> [google](#requirement\_google) | 6.26.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | 6.26.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 6.26.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_artifact_registry"></a> [artifact\_registry](#module\_artifact\_registry) | GoogleCloudPlatform/artifact-registry/google | ~> 0.3 |
| <a name="module_folder_iam"></a> [folder\_iam](#module\_folder\_iam) | terraform-google-modules/iam/google//modules/folders_iam | ~> 8.1 |
| <a name="module_project"></a> [project](#module\_project) | terraform-google-modules/project-factory/google | ~> 18.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_project_metadata.default](https://registry.terraform.io/providers/hashicorp/google/6.26.0/docs/resources/compute_project_metadata) | resource |
| [google_folder.boskos](https://registry.terraform.io/providers/hashicorp/google/6.26.0/docs/resources/folder) | resource |

## Inputs

No inputs.

## Outputs

No outputs.
