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

resource "vsphere_role" "capv-ci-content-library" {
  name = "capv-ci-content-library"
  role_privileges = [
    "ContentLibrary.DownloadSession",
    "ContentLibrary.ReadStorage",
    "ContentLibrary.SyncLibraryItem",
  ]
}

resource "vsphere_role" "capv-ci" {
  name = "capv-ci"
  role_privileges = [
    "Cns.Searchable",
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
    "VirtualMachine.Config.CPUCount",
    "VirtualMachine.Config.ChangeTracking",
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
    "VirtualMachine.State.CreateSnapshot",
    "VirtualMachine.State.RemoveSnapshot",
  ]
}
