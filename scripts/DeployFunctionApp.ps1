param (
    [string]$ResourceGroupName,
    [string]$GithubURL,
    [string]$FunctionAppName,
    [string]$VirtualMachineName
)

Install-Module -Name Az -Repository PSGallery -Force

Import-Module -Name Az

Connect-AzAccount -Identity

Invoke-WebRequest -Uri $GithubURL -OutFile "C:\FunctionApp"

$compress = @{
    Path = "C:\FunctionApp"
    CompressionLevel = "Fastest"
    DestinationPath = "C:\FunctionApp.zip"
}
Compress-Archive @compress

Publish-AzWebApp -ResourceGroupName $ResourceGroupName -Name $FunctionAppName -ArchivePath "C:\FunctionApp.zip"

# Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -Force
