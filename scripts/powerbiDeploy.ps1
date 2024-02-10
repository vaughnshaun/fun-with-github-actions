param ($ClientId, $TenantId, $ClientSecret, $reportsPath,
$workspaceName ="FromGithub", 
$reportsFolder = "**", 
$reportPrefix = "", 
$dataSetConnections = '[
{
  "name": "website",
  "newValue": "https://learn.microsoft.com/en-us/aspnet/core/blazor/?view=aspnetcore-8.0"
},
{
  "name": "frank",
  "newValue": "test"
},
{
  "name": "DatabaseServer",
  "newValue": "TestThisServer"
},
{
  "name": "DatabaseName",
  "newValue": "TestThisDatabase"
}
]')
#$ErrorActionPreference = "Stop"
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module -Name MicrosoftPowerBIMgmt.Workspaces
Install-Module -Name MicrosoftPowerBIMgmt.Reports
Install-Module -Name MicrosoftPowerBIMgmt.Profile
Install-Module -Name MicrosoftPowerBIMgmt.Data

# Get all reports
$searchPath = ""
if ($reportsPath -ne $null){  
	$searchPath = $reportsPath
}
else {
	$searchPath = $($pwd.Path + "\"+ $reportsFolder +"\**\*.pbix")
}

# Display params
echo Preparing to upload
Write-Host $("Workspace: " + $workspaceName)
Write-Host $("Reports path: " + $searchPath)
Write-Host $("Report Prefix: " + $reportPrefix)
Write-Host $("Dataset Connections: " + $dataSetConnections)

$body = $('{ "updateDetails":' + $dataSetConnections + '}').ToString()
  
$allReports = Get-ChildItem -Path $searchPath -Recurse

# Create Secure Strings
$SecurePassword = ConvertTo-SecureString $ClientSecret -Force -AsPlainText
$Credential = New-Object Management.Automation.PSCredential($ClientId, $SecurePassword)

# Connect to the Power BI service
Connect-PowerBIServiceAccount -ServicePrincipal -TenantId $TenantId -Credential $Credential

# Get the workspace
$workspaceId = ( Get-PowerBIWorkspace -Name $workspaceName ).id

# Deploy all reports
foreach ($report in $allReports)
{
	$reportName = $reportPrefix + $report.Name
	$reportPath = $report.FullName
	$baseReportName = $reportPrefix + $report.BaseName

	echo ("uploading " + $reportPath)
	New-PowerBIReport -Path $reportPath -Name $reportName -WorkspaceId $workspaceId -ConflictAction CreateOrOverwrite
	$datasetId = (Get-PowerBIReport -Name $baseReportName -WorkspaceId $workspaceId).DatasetId

	# Update connections for report dataset
	$urlUpdateParams = $("https://api.powerbi.com/v1.0/myorg/groups/" + $workspaceId + "/datasets/"+ $datasetId +"/Default.UpdateParameters")
	echo $urlUpdateParams

	$content = 'application/json'

	#Take over ownership
	$TakeOverUrl = $("https://api.powerbi.com/v1.0/myorg/groups/" + $workspaceId + "/datasets/"+ $datasetId +"/Default.TakeOver")
	Invoke-PowerBIRestMethod -Url $TakeOverUrl -Method Post

	# Updates Dataset Parameters
	try{
	  Invoke-PowerBIRestMethod -Url $urlUpdateParams -Method Post -Body $body -ContentType $content -ErrorAction Stop
	}
	catch [System.AggregateException]{
	  $exceptionCode = ""
	  if($PSItem.Exception.InnerException -ne $null)
	  {
		$innerExMsg = $PSItem.Exception.InnerException.Message
		$exceptionCode = ($innerExMsg | ConvertFrom-Json).code
		Write-Host $exceptionCode
	  }
	  
	  if ($exceptionCode -eq "ItemNotFound")
	  {
		  Write-Warning "All parameters not updated. This is ok. The shared connections will still be updated"
	  }
	  else 
	  {
		Write-Error $PSItem.Exception
		throw $PSItem
	  }
	}

	# Refresh Dataset
	$refreshUrl = $("https://api.powerbi.com/v1.0/myorg/groups/" + $workspaceId + "/datasets/"+ $datasetId +"/refreshes")
	Invoke-PowerBIRestMethod -Url $refreshUrl -Method Post
}

Disconnect-PowerBIServiceAccount

#Set-ExecutionPolicy Default