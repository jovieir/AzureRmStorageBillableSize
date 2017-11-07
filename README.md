# AzureRmStorageBillableSize
PowerShell script to determine the billable size for a storage account or a container inside a storage account.

Based on the official existing version in Classic - https://gallery.technet.microsoft.com/scriptcenter/Get-Billable-Size-of-32175802?ranMID=24542&ranEAID=je6NUbpObpQ&ranSiteID=je6NUbpObpQ-vcVQnsHe8MvUwgCu8R7wLw&tduid=(0d3c2c955e1b5e0a4c3ae0e5f37f838e)(256380)(2459594)(je6NUbpObpQ-vcVQnsHe8MvUwgCu8R7wLw)()

Reworked to work on ARM.

Step-by-step:

1º Login to your subscription (Login-AzureRmAccount).
2º Invoke the script Get-AzureRmStorageBillableSize -StorageAccountName <storage account name> -ResourceGroupName <RG name> -ContainerName <container name>

