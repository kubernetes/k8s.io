/*
Copyright 2024 The Kubernetes Authors.

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

resource "vsphere_content_library" "capv" {
  name            = "capv"
  description     = "Content Library for CAPV."
  storage_backing = [data.vsphere_datastore.datastore.id]
}

# TODO: consider if this should be pure bash instead?

resource "terraform_data" "ova_templates" {
  depends_on = [vsphere_content_library.capv]

  triggers_replace = sha512(file("${path.module}/hack/ensure_ova_from_github.sh"))

  provisioner "local-exec" {
    when    = create
    command = "${path.module}/hack/ensure_ova_from_github.sh"
    environment = {
      "GOVC_URL"              = "${var.vsphere_user}:${var.vsphere_password}@${var.vsphere_server}"
      "GOVC_INSECURE"         = "true"
      "DEBUG"                 = "true"
      "GITHUB_CA_CERTIFICATE" = "${var.github_ca_certificate}"
      "GITHUB_CA_THUMBPRINT"  = "${var.github_ca_thumbprint}"
      "CONTENT_LIBRARY_NAME"  = "${vsphere_content_library.capv.name}"
      "TEMPLATES_FOLDER"      = "${vsphere_folder.templates.path}"
      "DATASTORE"             = "${data.vsphere_datastore.datastore.name}"
      "RESOURCE_POOL"         = "/${data.vsphere_datacenter.datacenter.name}/host/${data.vsphere_compute_cluster.compute_cluster.name}/Resources/${vsphere_resource_pool.templates.name}"
      "URL"                   = "${each.value}"
    }
    interpreter = ["/bin/bash", "-c"]
  }

  for_each = var.ova_templates
}
