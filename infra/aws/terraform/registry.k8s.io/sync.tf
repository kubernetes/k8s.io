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

locals {
  // When we complete the initial datasync, remove the region from this list
  // aws ec2 describe-regions --all-regions --query "Regions[].RegionName" --output json | jq .[] | awk '{print $0","}' | sort --version-sort
  new_regions = [
    # "foobar"
  ]
}

module "s3_locations" {
  source = "github.com/upodroid/terraform-aws-datasync//modules/datasync-locations?ref=main"
  s3_locations = concat(
    [
      {
        name                             = "source-bucket"
        s3_bucket_arn                    = module.us-east-2.bucket_arn
        subdirectory                     = "/"
        create_role                      = false
        s3_config_bucket_access_role_arn = "arn:aws:iam::513428760722:role/AWSDataSyncS3BucketAccess"
        region                           = "us-east-2"
      },
    ],
    [
      for idx, region in local.new_regions :
      {
        name                             = "${region}"
        s3_bucket_arn                    = module.s3_buckets[region].bucket_arn
        subdirectory                     = "/"
        create_role                      = false
        s3_config_bucket_access_role_arn = "arn:aws:iam::513428760722:role/AWSDataSyncS3BucketAccess"
        region                           = "${region}"
      }
    ]
  )
}

module "s3_to_s3_tasks" {
  source = "github.com/upodroid/terraform-aws-datasync//modules/datasync-task?ref=main"
  datasync_tasks = [
    for idx, region in local.new_regions :
    {
      name                     = "${region}"
      source_location_arn      = "arn:aws:datasync:us-east-2:513428760722:location/loc-050a6ce9904237d71"
      destination_location_arn = module.s3_locations.s3_locations[region].arn
      task_mode                = "ENHANCED"
      options = {
        verify_mode       = "ONLY_FILES_TRANSFERRED" # Enhanced mode supports ONLY_FILES_TRANSFERRED or NONE
        gid               = "NONE"
        posix_permissions = "NONE"
        uid               = "NONE"
      }
      schedule_expression = "cron(0 0 * * ? *)" # Run at 00:00 every day, we only need the first run.
      region              = "us-east-2"
    }
  ]
}
