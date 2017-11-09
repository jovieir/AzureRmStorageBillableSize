# AzureRmStorageBillableSize
PowerShell script that determines the billable size for a storage account, a container inside a storage account, or specific page blobs.

Based on the official existing version in Classic - https://gallery.technet.microsoft.com/scriptcenter/Get-Billable-Size-of-32175802

Reworked to work on ARM, with a few new features.

-- Instructions:

Open an elevated PowerShell command and run the following commands for:

- Storage Account billable summary: 
  .\AzureRmStorageBillableSize.ps1 -StorageAccountName <SA Name> -ResourceGroupName <RG Name>
- Container billable summary: 
    .\AzureRmStorageBillableSize.ps1 -StorageAccountName "mystorageaccountname" -ResourceGroupName "RG name" -ContainerName "mycontainername"
- Blob(s) billable summary: 
    .\AzureRmStorageBillableSize.ps1 -StorageAccountName "mystorageaccountname" -ResourceGroupName "RG name" -ContainerName "mycontainername" -BlobNamesArray "file1.vhd" 
  
Parameters:

- StorageAccountName <string> [Required]
  :The name of the storage account
- ResourceGroupName <string> [Required]
  :The name of the resource group where the storage account resides.
- ContainerName <string> [Optional]
  :The name of the container. If specified, the script will only calculate the size of the container and the blobs within it.
- BlobNames <string array> [Optional]
  :The name(s) of the Page Blobs. If specified, the script will only calculate the size of the blobs. [ContainerName parameter is required with this parameter]
- Authenticated <switch> [Optional]
  :If the user is not authenticated, it'll be prompted to do so and choose a subscription.
