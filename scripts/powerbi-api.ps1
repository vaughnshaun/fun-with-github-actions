param ($ClientId, $TenantId, $ClientSecret)

Function Get-PowerBIGroupPath {
    Param(
        [parameter(Mandatory = $true)]$WorkspaceName,
        [parameter(Mandatory = $true)]$AccessToken,
        [parameter()][bool]$Create = $false
    )
    $groupsPath = ""
    if ($WorkspaceName -eq "me") {
        $groupsPath = "/myorg"
    }
    else {
        Write-Host "Getting Power BI Workspace properties; $WorkspaceName"
        $workspace = Get-PowerBIWorkspace -WorkspaceName $WorkspaceName -AccessToken $AccessToken -Verbose

        if ($Create -And !$workspace) {
            $workspace = New-PowerBIWorkSpace -WorkspaceName $WorkspaceName -AccessToken $AccessToken
        }
        elseif (!$workspace) {
            Throw "Power BI Workspace: $WorkspaceName does not exist"
        }
        $groupId = $workspace.Id

        #writing Workspace Id
        Write-Host "##vso[task.setvariable variable=PowerBIActions.WorkspaceId]$groupId"

        $groupsPath = "/myorg/groups/$groupId"
    }

    return $groupsPath
}

Function New-PowerBIWorkSpace {
    Param(
        [parameter(Mandatory = $true)]$WorkspaceName,
        [parameter(Mandatory = $true)]$AccessToken
    )

    $workspace = Get-PowerBIWorkspace -WorkspaceName $WorkspaceName -AccessToken $AccessToken -Verbose

    if ($workspace) {
        Write-Host "Workspace: $WorkspaceName already exists"
    }
    else {
        Write-Host "Trying to create workspace: $WorkspaceName"
        $url = $powerbiUrl + "/myorg/groups"

        $body = @{
            name = $WorkspaceName
        } | ConvertTo-Json
    
        $result = Invoke-API -Url $url -Method "Post" -AccessToken $AccessToken -Body $body -ContentType "application/json"
        
        Write-Host "Workspace: $WorkspaceName created!"
        Write-Output $result
    }
}

Function Get-PowerBIWorkspace {
    Param(
        [parameter(Mandatory = $true)][string]$WorkspaceName,
        [parameter(Mandatory = $true)]$AccessToken
    )

    $groupsUrl = $powerbiUrl + '/myorg/groups'
    $result = Invoke-API -Url $groupsUrl -Method "Get" -AccessToken $AccessToken -Verbose
    $groups = $result.value

    $workspace = $null;
    if (-not [string]::IsNullOrEmpty($WorkspaceName)) {

        Write-Verbose "Trying to find workspace: $WorkspaceName"		
        $groups = @($groups | Where-Object name -eq $WorkspaceName)
    
        if ($groups.Count -ne 0) {
            $workspace = $groups[0]		
        }				
    }

    return $workspace
}


Function Get-PowerBIGroupPath {
    Param(
        [parameter(Mandatory = $true)]$WorkspaceName,
        [parameter(Mandatory = $true)]$AccessToken,
        [parameter()][bool]$Create = $false
    )
    $groupsPath = ""
    if ($WorkspaceName -eq "me") {
        $groupsPath = "/myorg"
    }
    else {
        Write-Host "Getting Power BI Workspace properties; $WorkspaceName"
        $workspace = Get-PowerBIWorkspace -WorkspaceName $WorkspaceName -AccessToken $AccessToken -Verbose

        if ($Create -And !$workspace) {
            $workspace = New-PowerBIWorkSpace -WorkspaceName $WorkspaceName -AccessToken $AccessToken
        }
        elseif (!$workspace) {
            Throw "Power BI Workspace: $WorkspaceName does not exist"
        }
        $groupId = $workspace.Id

        #writing Workspace Id
        Write-Host "##vso[task.setvariable variable=PowerBIActions.WorkspaceId]$groupId"

        $groupsPath = "/myorg/groups/$groupId"
    }

    return $groupsPath
}

Function Publish-PowerBIFile {
    Param(
        [parameter(Mandatory = $true)]$WorkspaceName,
        [parameter(Mandatory = $true)]$FilePattern,
        [parameter()][bool]$Create = $false,
        [parameter()][bool]$Overwrite = $false,
        [parameter(Mandatory = $true)]$AccessToken
    )

    $GroupPath = Get-PowerBIGroupPath -WorkspaceName $WorkspaceName -AccessToken $AccessToken -Create $Create
    
    $searchedFiles = Get-ChildItem $filePattern
    foreach ($foundFile in $searchedFiles) {
        $directory = $foundFile.DirectoryName
        $file = $foundFile.Name
    
        $filePath = "$directory\$file"
        Write-Host "Trying to publish PowerBI File: $FilePath"
    
        #Check for exisiting report
        $fileNamewithoutextension = [IO.Path]::GetFileNameWithoutExtension($filePath)
        Write-Host "Checking for existing Reports with the name: $fileNamewithoutextension"
    
        $report = Get-PowerBIReport -GroupPath $GroupPath -AccessToken $AccessToken -ReportName $fileNamewithoutextension -Verbose
        
        $publish = $true
        $nameConflict = "Abort"
        if ($report) {
            Write-Verbose "Reports exisits"
            if ($Overwrite) {
                Write-Verbose "Reports exisits and needs to be overwritten"
                $nameConflict = "Overwrite"
            }
            else {
                $publish = $false
                Write-Warning "Report already exists"
            }
        }
       
        if ($publish) {
            #Import PowerBi file
            Write-Host "Importing PowerBI File"
            Import-PowerBiFile -GroupPath $GroupPath -AccessToken $AccessToken -Path $FilePath -Conflict $nameConflict -Verbose
        }
    }
}

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