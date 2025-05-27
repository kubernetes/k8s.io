/*
Copyright 2025 The Kubernetes Authors.

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

# Permission roles required for the CI user.
# Assignment of the roles is done via iam_roleassignments.tf, projects.tf
# and manually via `scripts/ensure-users-permissions.sh`.

# Allows the ci user to e.g. create VMs, Resource Pools, Folders, ... during tests.
resource "vsphere_role" "vsphere-ci" {
  name = "vsphere-ci"
  role_privileges = [
    "Cns.Searchable",
    "Cryptographer.Access",
    "Cryptographer.Clone",
    "Datastore.AllocateSpace",
    "Datastore.Browse",
    "Datastore.FileManagement",
    "Folder.Create",
    "Folder.Delete",
    "Global.SetCustomField",
    "Network.Assign",
    "Resource.AssignVMToPool",
    "Resource.CreatePool",
    "Resource.DeletePool",
    "Sessions.GlobalMessage",
    "Sessions.ValidateSession",
    "StorageProfile.View",
    "VApp.ApplicationConfig",
    "VApp.Import",
    "VApp.InstanceConfig",
    "VirtualMachine.Config.AddExistingDisk",
    "VirtualMachine.Config.AddNewDisk",
    "VirtualMachine.Config.AddRemoveDevice",
    "VirtualMachine.Config.AdvancedConfig",
    "VirtualMachine.Config.Annotation",
    "VirtualMachine.Config.ChangeTracking",
    "VirtualMachine.Config.CPUCount",
    "VirtualMachine.Config.DiskExtend",
    "VirtualMachine.Config.EditDevice",
    "VirtualMachine.Config.HostUSBDevice",
    "VirtualMachine.Config.ManagedBy",
    "VirtualMachine.Config.Memory",
    "VirtualMachine.Config.RawDevice",
    "VirtualMachine.Config.RemoveDisk",
    "VirtualMachine.Config.Resource",
    "VirtualMachine.Config.Settings",
    "VirtualMachine.Config.SwapPlacement",
    "VirtualMachine.Config.UpgradeVirtualHardware",
    "VirtualMachine.Interact.ConsoleInteract",
    "VirtualMachine.Interact.DeviceConnection",
    "VirtualMachine.Interact.PowerOff",
    "VirtualMachine.Interact.PowerOn",
    "VirtualMachine.Interact.PutUsbScanCodes",
    "VirtualMachine.Interact.SetCDMedia",
    "VirtualMachine.Interact.SetFloppyMedia",
    "VirtualMachine.Inventory.Create",
    "VirtualMachine.Inventory.CreateFromExisting",
    "VirtualMachine.Inventory.Delete",
    "VirtualMachine.Provisioning.Clone",
    "VirtualMachine.Provisioning.CloneTemplate",
    "VirtualMachine.Provisioning.CreateTemplateFromVM",
    "VirtualMachine.Provisioning.DeployTemplate",
    "VirtualMachine.Provisioning.DiskRandomRead",
    "VirtualMachine.Provisioning.GetVmFiles",
    "VirtualMachine.Provisioning.MarkAsTemplate",
    "VirtualMachine.Provisioning.MarkAsVM",
    "VirtualMachine.State.CreateSnapshot",
    "VirtualMachine.State.RemoveSnapshot",
  ]
}

# allows the ci user to browse CNS and storage profiles.
resource "vsphere_role" "vsphere-ci-readonly" {
  name = "vsphere-ci-readonly"
  role_privileges = [
    "Cns.Searchable",
    "StorageProfile.View"
  ]
}


# templates-ci allows users access to the templates folder to clone templates to virtual machines.
resource "vsphere_role" "templates-ci" {
  name = "templates-ci"
  role_privileges = [
    "VirtualMachine.Provisioning.Clone",
    "VirtualMachine.Provisioning.CloneTemplate",
    "VirtualMachine.Provisioning.DeployTemplate",
  ]
}
