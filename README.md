# AzureRmStorageBillableSize
PowerShell script that determines the billable size for a storage account, a container inside a storage account, or specific page blobs.

Based on the official existing version in Classic - https://gallery.technet.microsoft.com/scriptcenter/Get-Billable-Size-of-32175802?ranMID=24542&ranEAID=je6NUbpObpQ&ranSiteID=je6NUbpObpQ-vcVQnsHe8MvUwgCu8R7wLw&tduid=(0d3c2c955e1b5e0a4c3ae0e5f37f838e)(256380)(2459594)(je6NUbpObpQ-vcVQnsHe8MvUwgCu8R7wLw)()

Reworked to work on ARM.

Instructions:

- Open an elevated PowerShell command and run .\AzureRmStorageBillableSize.ps1 -StorageAccountName <SA Name> -ResourceGroupName <RG Name>
  
The script takes the following parameters:

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
