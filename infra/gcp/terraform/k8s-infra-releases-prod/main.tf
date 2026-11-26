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

module "project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.2"

  name            = "k8s-infra-releases-prod"
  project_id      = "k8s-infra-releases-prod"
  folder_id       = "455406320404" # Release Engineering
  billing_account = "018801-93540E-22A20E"

  # Sane project defaults
  default_service_account     = "keep"
  disable_services_on_destroy = false
  create_project_sa           = false
  random_project_id           = false
  auto_create_network         = true


  activate_apis = [
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
    "storagetransfer.googleapis.com",
  ]
}

resource "google_service_account" "fastly_reader" {
  project     = module.project.project_id
  account_id  = "fastly-reader"
  description = "Used by Fastly for read-only actions against the bucket"
}

resource "google_storage_hmac_key" "fastly_reader_key" {
  project               = module.project.project_id
  service_account_email = google_service_account.fastly_reader.email
}


module "release_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 12.3"

  name       = "767373bbdcb8270361b96548387bf2a9ad0d48758c35"
  project_id = module.project.project_id
  location   = "us-central1"

  iam_members = [
    {
      role   = "roles/storage.objectAdmin"
      member = "serviceAccount:648026197307@cloudbuild.gserviceaccount.com"
    },
    {
      // The level 3 signing build reads the staged files.
      role   = "roles/storage.objectViewer"
      member = "serviceAccount:krel-provenance-builder@k8s-releng-prod.iam.gserviceaccount.com"
    },
    {
      // The level 3 stage builds list the stage directory. Listing can't be
      // limited to a prefix, so they can read the whole bucket.
      role   = "roles/storage.objectViewer"
      member = "serviceAccount:krel-stage@k8s-release.iam.gserviceaccount.com"
    }
  ]
}

// The level 3 signing build writes the stage and final provenance next to
// the staged files, and nothing else: it can't change the files it vouches
// for, and krel release publishes the provenance. For the images it can, as
// a writer of the staging registry. The bucket module doesn't support IAM
// conditions, so this binding lives outside of it.
resource "google_storage_bucket_iam_member" "provenance_builder_writer" {
  bucket = module.release_bucket.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:krel-provenance-builder@k8s-releng-prod.iam.gserviceaccount.com"

  condition {
    title = "stage-provenance-write"
    expression = join(" && ", [
      "resource.name.startsWith(\"projects/_/buckets/${module.release_bucket.name}/objects/stage/\")",
      "(resource.name.endsWith(\"/provenance-v2.json\") || resource.name.endsWith(\"/image-provenance-v2.json\") || resource.name.endsWith(\"/final-provenance-v2.json\"))",
    ])
  }
}

// The stage builds of the level 3 stage trigger write the stage directory,
// and nothing else: krel release publishes the release from it. The bucket
// module doesn't support IAM conditions, so this binding lives outside of it.
resource "google_storage_bucket_iam_member" "krel_stage" {
  bucket = module.release_bucket.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:krel-stage@k8s-release.iam.gserviceaccount.com"

  condition {
    title      = "stage"
    expression = "resource.name.startsWith(\"projects/_/buckets/${module.release_bucket.name}/objects/stage/\")"
  }
}
