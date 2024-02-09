param ($ClientId, $TenantId, $ClientSecret)
#Set-ExecutionPolicy RemoteSigned
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module -Name MicrosoftPowerBIMgmt
Install-Module -Name MicrosoftPowerBIMgmt.Workspaces
Install-Module -Name MicrosoftPowerBIMgmt.Data
Install-Module -Name MicrosoftPowerBIMgmt.Reports

# Create Secure Strings

$SecurePassword = ConvertTo-SecureString $ClientSecret -Force -AsPlainText
$Credential = New-Object Management.Automation.PSCredential($ClientId, $SecurePassword)


# Connect to the Power BI service
Connect-PowerBIServiceAccount -ServicePrincipal -TenantId $TenantId -Credential $Credential

#Set-ExecutionPolicy Default