param ($ClientId, $TenantId, $ClientSecret)
#Set-ExecutionPolicy RemoteSigned
Set-PSRepository PSGallery -InstallationPolicy Trusted
#Install-Module -Name MicrosoftPowerBIMgmt
Install-Module -Name MicrosoftPowerBIMgmt.Workspaces
#Install-Module -Name MicrosoftPowerBIMgmt.Data
Install-Module -Name MicrosoftPowerBIMgmt.Reports
Install-Module -Name MicrosoftPowerBIMgmt.Profile
#Install-Module -Name Microsoft.PowerShell.Utility

# Create Secure Strings

$SecurePassword = ConvertTo-SecureString $ClientSecret -Force -AsPlainText
$Credential = New-Object Management.Automation.PSCredential($ClientId, $SecurePassword)


# Connect to the Power BI service
Connect-PowerBIServiceAccount -ServicePrincipal -TenantId $TenantId -Credential $Credential

# Deploy report
#$workspaceId = [System.Guid]::Parse("bb872616-e922-4d7f-bbb0-05bf3930076a")

$workspaceName = "FromGitHub"
$workspaceId = ( Get-PowerBIWorkspace -Name $workspaceName ).id
$reportName = "[DEV] MyReport"
$reportPath = (Get-Location).Path + "\Business Reports\ParametersWithWeb\ParametersWithWeb.pbix"
$errors = (Get-Location).Path + "\errors.txt"
echo ("uploading " + $reportPath)

#New-PowerBIReport -Path $reportPath -Name $reportName -Workspace ( Get-PowerBIWorkspace -Name $workspaceName ) -ConflictAction CreateOrOverwrite
New-PowerBIReport -Path $reportPath -Name $reportName -WorkspaceId $workspaceId -ConflictAction CreateOrOverwrite

# Update connections for all datasets
$datasetsArray = (Get-PowerBIDataset -WorkspaceId $workspaceId)

foreach ($dataSet in $datasetsArray)
{
  Write-Host $dataSet.id
$datasetId = $dataSet.id

# Update Parameters URL
#$datasetId = "f91b0f99-4b81-44ae-b3c2-6267e1d7780f"
#$urlUpdateParams = $("https://api.powerbi.com/v1.0/myorg/datasets/" + $datasetId + "/Default.UpdateParameters")
$urlUpdateParams = $("https://api.powerbi.com/v1.0/myorg/groups/" + $workspaceId + "/datasets/"+ $datasetId +"/Default.UpdateParameters")

echo $urlUpdateParams
# Update Parameters Body
$body = '{
  "updateDetails": [
    {
      "name": "website",
      "newValue": "https://learn.microsoft.com/en-us/aspnet/core/blazor/?view=aspnetcore-8.0"
    }
  ]
}'

$content = 'application/json'

#Take over ownership
$TakeOverUrl = $("https://api.powerbi.com/v1.0/myorg/groups/" + $workspaceId + "/datasets/"+ $datasetId +"/Default.TakeOver")
Invoke-PowerBIRestMethod -Url $TakeOverUrl -Method Post

# Bind
#$bindGatewayUrl = "https://api.powerbi.com/v1.0/myorg/groups/" + $workspaceId + "/datasets/"+ $datasetId +"/Default.BindToGateway"
#$gatewayId = "7ba540f6-e28d-47aa-b6c0-727f81ab0fee"
#$datasourceId = "267e3368-5e04-4442-a8a2-36813b58975c"
#$bindBody = '{
#   "gatewayObjectId": "7ba540f6-e28d-47aa-b6c0-727f81ab0fee",
#   "datasourceObjectIds": ["267e3368-5e04-4442-a8a2-36813b58975c", "df1aa32b-ed8e-4827-af90-7b222226b05a", "afe17b10-aacf-4864-842f-b04d76ccf25b"]
#}'
#Invoke-PowerBIRestMethod -Url $bindGatewayUrl -Method Post -Body $bindBody

# Updates Dataset Parameters
Invoke-PowerBIRestMethod -Url $urlUpdateParams -Method Post -Body $body -ContentType $content
#$headers = Get-PowerBIAccessToken
#Invoke-RestMethod -Headers $headers -Uri 'https://api.powerbi.com/v1.0/myorg/groups'
#Invoke-RestMethod -Headers $headers -Uri $urlUpdateParams -Method Post -Body $body -ContentType $content
}

# Refresh Dataset
$refreshUrl = $("https://api.powerbi.com/v1.0/myorg/groups/" + $workspaceId + "/datasets/"+ $datasetId +"/refreshes")
Invoke-PowerBIRestMethod -Url $refreshUrl -Method Post


Disconnect-PowerBIServiceAccount

#Set-ExecutionPolicy Default