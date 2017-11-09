<#
.SYNOPSIS
    Calculates cost of all blobs in a container or storage account.
.DESCRIPTION
    Enumerates all blobs in either one container or one storage account and sums
    up all costs associated.  This includes all block and page blobs, all metadata
    on either blobs or containers.  It also includes both committed and uncommitted
    blocks in the case that a blob is partially uploaded.
 
    The details of the calculations can be found in this post:
    http://blogs.msdn.com/b/windowsazurestorage/archive/2010/07/09/understanding-windows-azure-storage-billing-bandwidth-transactions-and-capacity.aspx
 
.EXAMPLE
    .\AzureRmStorageBillableSize.ps1 -StorageAccountName "mystorageaccountname"
    .\AzureRmStorageBillableSize.ps1 -StorageAccountName "mystorageaccountname" -ResourceGroupName "RG name" -ContainerName "mycontainername"
    .\AzureRmStorageBillableSize.ps1 -StorageAccountName "mystorageaccountname" -ResourceGroupName "RG name" -ContainerName "mycontainername" -BlobNamesArray "file1.vhd"
    .\AzureRmStorageBillableSize.ps1 -StorageAccountName "mystorageaccountname" -ResourceGroupName "RG name" -ContainerName "mycontainername" -BlobNamesArray "file1.vhd","file2.vhd","file3.vhd"

#>
 
param(
     # The name of the storage account to enumerate.
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    # The name of the resource group name where the storage account resides.
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
 
    # The name of the storage container to enumerate.
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ContainerName,

    # The name of the blob to enumerate.
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$BlobNamesArray,

    # Boolean value to authenticate (if not already done)
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [switch]$Authenticate
)
 
# The script has been tested on Powershell 5.0
Set-StrictMode -Version 3
 
# Following modifies the Write-Verbose behavior to turn the messages on globally for this session
#$VerbosePreference = "Continue"
 
# Check if Windows Azure Powershell is avaiable
if ((Get-Module -ListAvailable Azure) -eq $null)
{
    Write-Output "Windows Azure Powershell not found! Installing Module..."
    Install-Module AzureRm -Force
}

<#
.SYNOPSIS
   Gets the size (in bytes) of a blob.
.DESCRIPTION
   Blob consume storage formulas
   
   Base value = 124 bytes of overhead (Last Modified Time, Size, Cache-Control, Content-Type, Content-MD5, Lease, etc)
   Blob Name = NameLength * 2 (Unicode)
   Metadata (each field) = 3 bytes + Name Length + Length of Value

   For Block Blobs, add:
      8 bytes (Block list) + SizeInBytes
   For Page Blobs, add:
      (12 bytes * number of nonconsecutive page ranges with data) + SizeInBytes (data in unique pages stored)
    
.INPUTS
   $Blob - The blob to calculate the size of.
.OUTPUTS
   $blobSizeInBytes - The calculated sizeo of the blob.
#>
function Get-BlobBytes
{
    param (
        [Parameter(Mandatory=$true)]
        [Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageBase]$Blob)
 
    
    # Base values 
    $blobSizeInBytes = 124 + $Blob.Name.Length * 2
 
    # Fetch metadata
    $BlobMetadata = $Blob.ICloudBlob.Metadata
    foreach($BlobMetadataValue in $BlobMetadata.Keys)
    {
        $blobSizeInBytes += 3 + $BlobMetadataValue.Length + $BlobMetadata[$BlobMetadataValue].Length
    }
     
    ## Calculate the Size 

    if($storageAccount.Sku.Tier -eq "Standard") ## Standard
    {
        if ($Blob.BlobType -eq "BlockBlob")
        {
            $blobSizeInBytes += 8
            $Blob.ICloudBlob.DownloadBlockList() | ForEach-Object { $blobSizeInBytes += $_.Length + $_.Name.Length }
        }
        elseif (($Blob.BlobType -eq "PageBlob") -and ($Blob.Name.Substring($Blob.Name.LastIndexOf('.'),4) -eq '.vhd'))
        {
            $Blob.ICloudBlob.GetPageRanges() | ForEach-Object { $blobSizeInBytes += 12 + $_.EndOffset - $_.StartOffset }
        }
    }else{ ## Premium
        if($Blob.BlobType -eq "PageBlob")
        {
            $blobSizeInBytes += $Blob.Length
        }
    }

    return $blobSizeInBytes
}
 
<#
.SYNOPSIS
   Gets the size (in bytes) of a blob container.
.DESCRIPTION
   Given a container name, sum up all bytes consumed including the container itself and any metadata,
   all blobs in the container together with metadata, all committed blocks and uncommitted blocks.
.INPUTS
   $Container - The container to calculate the size of. 
.OUTPUTS
   $containerSizeInBytes - The calculated size of the container.
#>
function Get-ContainerBytes
{
    param (
        [Parameter(Mandatory=$true)]
        [Microsoft.WindowsAzure.Storage.Blob.CloudBlobContainer]$Container)
 
    # Base + name of container
    $containerSizeInBytes = 48 + $Container.Name.Length * 2
 
    # Get size of metadata
    $metadataEnumerator = $Container.Metadata.GetEnumerator()
    while ($metadataEnumerator.MoveNext())
    {
        $containerSizeInBytes += 3 + $metadataEnumerator.Current.Key.Length + 
                                     $metadataEnumerator.Current.Value.Length
    }

    # Get size for Shared Access Policies
    $containerSizeInBytes += $Container.GetPermissions().SharedAccessPolicies.Count * 512
 
    # Calculate size of all blobs.
    $blobCount = 0
    Get-AzureStorageBlob -Context $storageContext -Container $Container.Name | ForEach-Object { $containerSizeInBytes += Get-BlobBytes $_; $blobCount++ }
 
    return @{ "containerSize" = $containerSizeInBytes; "blobCount" = $blobCount }
}

# Validate user input for authentication, if not specified 
if($Authenticate -eq [Switch]::Present)
{
    ## Validate if the user
    Write-Host "Authentication flag not set, proceeding to authenticate user..." -ForegroundColor Yellow
    ## Auths the user to sub/tenant
    Login-AzureRmAccount
    ## Select the desired subscription
    Select-AzureRmSubscription | Out-GridView -PassThru -Title "Select an Azure Subscription"
}

$storageAccount = Get-AzureRmStorageAccount -StorageAccountName $StorageAccountName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if ($storageAccount -eq $null)
{
    throw "The storage account specified does not exist in this subscription."
}


# Instantiate a storage context for the storage account.
$storagePrimaryKey = (Get-AzureRmStorageAccountKey -StorageAccountName $StorageAccountName -ResourceGroupName $ResourceGroupName)[0].Value
$storageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $storagePrimaryKey

##If a specific blob is specified, skip container enumerating
if(($BlobNamesArray) -and ![string]::IsNullOrWhiteSpace($ContainerName))
{
    #Validates if the container exists
    $Container = Get-AzureStorageContainer -Context $storageContext -Name $ContainerName -ErrorAction SilentlyContinue
    if ($Container -eq $null)
    {
        throw "The specified container does not exist in this storage account."
    }

    #validates if the blob object exists
    if($BlobNamesArray.Count -eq 1)
    {
        $BlobName = $BlobNamesArray[0]
        $BlobObject = Get-AzureStorageBlob -Blob $BlobName -Container $ContainerName -Context $storageContext
        if ($BlobObject -eq $null)
        {
            throw "The specified blob does not exist in this container."
        }
    
        $SingleBlobSize = Get-BlobBytes -Blob $BlobObject -InformationAction SilentlyContinue
        Write-Output ("The $BlobName object estimated billable size is " + [Math]::Round($SingleBlobSize/1GB,2) +" GBs")
    }else{
        foreach($BlobName in $BlobNamesArray)
        {
            $BlobObject = Get-AzureStorageBlob -Blob $BlobName -Container $ContainerName -Context $storageContext
            if ($BlobObject -eq $null)
            {
                throw "The specified blob does not exist in this container."
            }
    
            $SingleBlobSize = Get-BlobBytes -Blob $BlobObject -InformationAction SilentlyContinue
            Write-Output ("The $BlobName object estimated billable size is " + [Math]::Round($SingleBlobSize/1GB,2) +" GBs")
        }
    }
}else{
    # Get a list of containers to process.
    $containers = New-Object System.Collections.ArrayList
    if (![string]::IsNullOrWhiteSpace($ContainerName))
    {
        $container = Get-AzureStorageContainer -Context $storageContext `
                          -Name $ContainerName -ErrorAction SilentlyContinue | 
                              ForEach-Object { $containers.Add($_) } | Out-Null
    }
    else
    {
        Get-AzureStorageContainer -Context $storageContext | ForEach-Object { $containers.Add($_) } | Out-Null
    }

    # Calculate size.
    $sizeInBytes = 0
    if ($containers.Count -gt 0)
    {
        $containers | ForEach-Object { 
                          $result = Get-ContainerBytes $_.CloudBlobContainer                   
                          $sizeInBytes += $result.containerSize
                          Write-Verbose ("Container '{0}' with {1} blobs has a size of {2:F2}MB." -f `
                              $_.CloudBlobContainer.Name, $result.blobCount, ($result.containerSize / 1MB))
        
                          }
        switch($storageAccount.Sku.Tier)
        {
            "Standard" { Write-Output ("Total size calculated for {0} containers is {1:F2}GB." -f $containers.Count, ($sizeInBytes / 1GB)) }
            "Premium"  { Write-Host "Premium Storage detected - Page Blobs are billed for their full allocated size!" -ForegroundColor Yellow ; Write-Output ("Total size calculated for {0} containers is {1:F2}GB." -f $containers.Count, ($sizeInBytes / 1GB)) }
        }
    }
    else
    {
        Write-Warning "No containers found to process in storage account '$StorageAccountName'."
    }
}
