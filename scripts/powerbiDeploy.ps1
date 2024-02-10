param ($ClientId, $TenantId, $ClientSecret, $reportsPath, $defaultSettingsPath,
$workspaceName ="FromGithub", 
$reportsFolder = "**", 
$reportPrefix = "", 
$env = "dev"
)
#$ErrorActionPreference = "Stop"
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module -Name MicrosoftPowerBIMgmt.Workspaces
Install-Module -Name MicrosoftPowerBIMgmt.Reports
Install-Module -Name MicrosoftPowerBIMgmt.Profile
Install-Module -Name MicrosoftPowerBIMgmt.Data

# Get the settings
$settings = $null
if(Test-Path -Path $defaultSettingsPath)
{
	$settings = (Get-Content -Path $defaultSettingsPath | ConvertFrom-Json)
}

# Get all reports

# Display params
echo Preparing to upload
Write-Host $("Workspace: " + $workspaceName)
Write-Host $("Reports path: " + $reportsPath)
Write-Host $("Report Prefix: " + $reportPrefix)
  
$allReports = Get-ChildItem -Path $reportsPath -Recurse -Include *.pbix

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
	$reportSettings = $settings
	
	# Override default settings with reports settings
	$reportSettingsPath = $($reportsPath + "/" + $report.BaseName + "/settings." + $env + ".json")
	if(Test-Path -Path $reportSettingsPath)
	{
		$reportSettings = (Get-Content -Path $reportSettingsPath | ConvertFrom-Json)
	}
	
	if($reportSettings -ne $null)
	{
		echo ("uploading " + $reportPath)
		New-PowerBIReport -Path $reportPath -Name $reportName -WorkspaceId $workspaceId -ConflictAction CreateOrOverwrite
		$datasetId = (Get-PowerBIReport -Name $baseReportName -WorkspaceId $workspaceId).DatasetId

		# Update connections for report dataset
		$body = $('{ "updateDetails":' + $reportSettings.Parameters + '}').ToString()
		Write-Host $("Update Parameters: " + $reportSettings.Parameters)
		$urlUpdateParams = $("https://api.powerbi.com/v1.0/myorg/groups/" + $workspaceId + "/datasets/"+ $datasetId +"/Default.UpdateParameters")
		echo $urlUpdateParams

		$content = 'application/json'

		#Take over ownership
		$TakeOverUrl = $("https://api.powerbi.com/v1.0/myorg/groups/" + $workspaceId + "/datasets/"+ $datasetId +"/Default.TakeOver")
		Invoke-PowerBIRestMethod -Url $TakeOverUrl -Method Post

		# Updates Dataset Parameters
		Invoke-PowerBIRestMethod -Url $urlUpdateParams -Method Post -Body $body -ContentType $content -ErrorAction Stop

		# Refresh Dataset
		$refreshUrl = $("https://api.powerbi.com/v1.0/myorg/groups/" + $workspaceId + "/datasets/"+ $datasetId +"/refreshes")
		Invoke-PowerBIRestMethod -Url $refreshUrl -Method Post	
	}
}

Disconnect-PowerBIServiceAccount

#Set-ExecutionPolicy Default