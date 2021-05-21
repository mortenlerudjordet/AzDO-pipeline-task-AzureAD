<#
	.SYNOPSIS
        Can run PS script/inline that targets AzureADPreview module.

        Make sure the Service Principal has been given correct access level to the AD graph API for what the logic executed tries to do

        !!! Only works with Windows Powershell 5.1 !!!
        This task is created using Azure PS v5 task as a template:
        https://github.com/microsoft/azure-pipelines-tasks/tree/master/Tasks/AzurePowerShellV5

    .DESCRIPTION
        Task will use the defined service connection / service principal to authenticate with AD graph API.
        Can run all functions contained in AzureADPreview module

    .NOTES
        AUTHOR: Microsoft & Morten Lerudjordet
#>
[CmdletBinding()]
param()

# Use bundled version of task SDK
if ( -not (Get-Module -Name "VSTSTaskSdk") )
{
    Write-Host -Object "##[command]Importing AzD Task SDK"
    Import-Module -Name "$PSScriptRoot\ps_modules\VstsTaskSdk"

}
else
{
    Write-Host -Object "##[command]AzD Task SDK module already imported"
}

try
{
    # Start session tracing
    Trace-VstsEnteringInvocation $MyInvocation

    #region Internal Variables
    $PSGalleryRepositoryName = "PSGallery"
    $ModuleNames = @("AzureADPreview", "MSAL.PS")
    $AuthContextScriptName = "InitializeContext.ps1"
    #endregion

    #region Powershell Module Repository Verification
    $Repositories = Get-PSRepository -ErrorAction Continue -ErrorVariable oErr
    if ($oErr)
    {
        Write-Error -Message "Failed to get registered repository information" -ErrorAction Stop
    }
    # Checking if PSGallery repository is available
    if(-not ($Repositories.Name -match $PSGalleryRepositoryName) )
    {
        Write-Host -Object "Adding $PSGalleryRepositoryName repository and setting it to trusted"
        Register-PSRepository -Name $PSGalleryRepositoryName -SourceLocation $PSGalleryRepositoryURL -PublishLocation $PSGalleryRepositoryURL -InstallationPolicy 'Trusted' -ErrorAction Continue -ErrorVariable oErr
        if($oErr)
        {
            Write-Host -Object "##vso[task.logissue type=error;]Failed to add $PSGalleryRepositoryName as trusted"
            Write-Error -Message "Failed to add $PSGalleryRepositoryName as trusted" -ErrorAction Stop
        }
    }
    else
    {
        if( (Get-PSRepository -Name $PSGalleryRepositoryName).InstallationPolicy -eq "Untrusted" )
        {
            Write-Host -Object "Trusting $PSGalleryRepositoryName repository"
            Set-PSRepository -Name $PSGalleryRepositoryName -InstallationPolicy 'Trusted' -ErrorAction Continue -ErrorVariable oErr
            if($oErr)
            {
                Write-Host -Object "##vso[task.logissue type=error;]Failed to set $PSGalleryRepositoryName as trusted"
                Write-Error -Message "Failed to set $PSGalleryRepositoryName as trusted" -ErrorAction Stop
            }
        }
        else
        {
            Write-Host -Object "$PSGalleryRepositoryName is already Trusted"
        }
    }
    #endregion

    # TODO: Clean up old version of a module

    #region Module version check
    [Collections.ArrayList]$ModulesToCheck = @()
    foreach($ModuleName in $ModuleNames)
    {
        $ModuleToAdd = [pscustomobject]@{ModuleName = $ModuleName;Update = "";NewVersion= "";CurrentVersion = "NA"}
        $null = $ModulesToCheck.Add($ModuleToAdd)
        $ModuleToAdd = $null
    }
    foreach($Module in $ModulesToCheck)
    {
        $AvailableModuleVersions = Get-Module -Name $($Module.ModuleName) -ListAvailable -ErrorAction Stop
        if(-not ($AvailableModuleVersions) )
        {
            # Force install of module as it does not exist on agent
            $Module.Update = $true
            $Module.NewVersion = (Find-Module -Name $($Module.ModuleName) -ErrorAction Stop).Version
        }
        else
        {
            $Module.Update = [version]($NewModuleVersion = Find-Module -Name $($Module.ModuleName) -ErrorAction Stop).Version -gt `
                             [version]($CurrentModuleVersion = $AvailableModuleVersions | Sort-Object -Property Version -Descending | Select-Object -First 1).Version
            if($NewModuleVersion)
            {
                $Module.NewVersion = $NewModuleVersion.Version.ToString()
            }
            if($CurrentModuleVersion)
            {
                $Module.CurrentVersion = $CurrentModuleVersion.Version.ToString()
            }
        }
    }
    #endregion
    #region Install Modules
    foreach($Module in $ModulesToCheck)
    {
        Write-Host -Object "Current version: $($Module.CurrentVersion) of module: $($Module.ModuleName)"

        if($Module.Update)
        {
            Write-Host -Object "Installing latest version: $($Module.NewVersion) of module: $($Module.ModuleName)"
            Write-Host -Object "##[command]Install-Module -Name $($Module.ModuleName) -Scope CurrentUser -AllowClobber -Force -Repository $PSGalleryRepositoryName -AcceptLicense"
            Install-Module -Name $($Module.ModuleName) -Scope CurrentUser -AllowClobber -Force -Repository $PSGalleryRepositoryName -AcceptLicense -ErrorAction Continue -ErrorVariable oErr
            if ($oErr)
            {
                if ($oErr -like "*No match was found for the specified search criteria and module name*")
                {
                    Write-Error -Message "Failed to find $($Module.ModuleName) in repository: $PSGalleryRepositoryName" -ErrorAction Continue
                }
                else
                {
                    Write-Error -Message "Failed to install module: $($Module.ModuleName) from $PSGalleryRepositoryName" -ErrorAction Continue
                }
                $oErr = $Null
            }
            else
            {
                Write-Host -Object "Installed new version: $($Module.NewVersion) of module: $($Module.ModuleName)"
            }
        }
        else
        {
            Write-Host -Object "Latest version: $($Module.NewVersion) of $($Module.ModuleName) already installed"
        }
    }
    #endregion

    #region Import Modules
    foreach($Module in $ModulesToCheck)
    {
        Write-Host -Object "##[command]Import-Module -Name $($Module.ModuleName) -Global"
        Import-Module -Name $($Module.ModuleName) -Global -ErrorAction Continue -ErrorVariable oErr
        if ($oErr)
        {
            Write-Error -Message "Failed to import module: $($Module.ModuleName)" -ErrorAction Stop
        }
    }
    #endregion

    #region AzD Task inputs
    # Import needed resources
    Write-Host -Object "##[command]Importing all task inputs"
    Import-VstsLocStrings -LiteralPath "$PSScriptRoot\Task.json"

    # Get inputs.
    $scriptType = Get-VstsInput -Name ScriptType -Require
    $scriptPath = Get-VstsInput -Name ScriptPath
    $scriptInline = Get-VstsInput -Name Inline
    $scriptArguments = Get-VstsInput -Name ScriptArguments
    $__vsts_input_errorActionPreference = Get-VstsInput -Name errorActionPreference
    $__vsts_input_failOnStandardError = Get-VstsInput -Name FailOnStandardError
    $input_workingDirectory = Get-VstsInput -Name workingDirectory -Require

    # Get task service connection details
    $serviceName = Get-VstsInput -Name ConnectedServiceNameARM -Require
    Write-Host -Object "##[command]Retrieving service connection details from AzD"
    $endpointObject = Get-VstsEndpoint -Name $serviceName -Require
    $endPoint = ConvertTo-Json $endpointObject
    #endregion

    #region Task setup logic
    # Validate the script path and args do not contains new-lines. Otherwise, it will
    # break invoking the script via Invoke-Expression.
    if ($scriptType -eq "FilePath")
    {
        if ($scriptPath -match '[\r\n]' -or [string]::IsNullOrWhitespace($scriptPath))
        {
            throw (Get-VstsLocString -Key InvalidScriptPath0 -ArgumentList $scriptPath)
        }
    }

    if ($scriptArguments -match '[\r\n]')
     {
        throw (Get-VstsLocString -Key InvalidScriptArguments0 -ArgumentList $scriptArguments)
    }

    # Generate the script contents.
    Write-Host -Object (Get-VstsLocString -Key 'GeneratingScript')
    $contents = @()
    $contents += "`$ErrorActionPreference = '$__vsts_input_errorActionPreference'"
    if ($env:system_debug -eq "true")
    {
        $contents += "`$VerbosePreference = 'continue'"
    }
    $AuthContextArgument = $null;
    if ($targetAADPs)
    {
        $AuthContextArgument = "-endpoint '$endPoint' -targetAADPs $targetAADPs"
    }
    else
    {
        $AuthContextArgument = "-endpoint '$endPoint'"
    }
    $contents += ". $PSScriptRoot\$AuthContextScriptName $AuthContextArgument"
    if ($scriptType -eq "InlineScript")
    {
        $contents += "$scriptInline".Replace("`r`n", "`n").Replace("`n", "`r`n")
    }
    else
    {
        $contents += ". '$("$scriptPath".Replace("'", "''"))' $scriptArguments".Trim()
    }

    # Write the script to disk.
    $__vstsAzPSScriptPath = [System.IO.Path]::Combine($env:Agent_TempDirectory, ([guid]::NewGuid().ToString() + ".ps1"));
    $joinedContents = [System.String]::Join(
        ([System.Environment]::NewLine),
        $contents)
    $null = [System.IO.File]::WriteAllText(
        $__vstsAzPSScriptPath,
        $joinedContents,
        ([System.Text.Encoding]::UTF8))

    # Prepare the external command values.
    #
    # Note, use "-Command" instead of "-File". On PowerShell V5, V4 and V3 when using "-File", terminating
    # errors do not cause a non-zero exit code.
    $powershellPath = Get-Command -Name powershell.exe -CommandType Application | Select-Object -First 1 -ExpandProperty Path

    Assert-VstsPath -LiteralPath $powershellPath -PathType 'Leaf'
    $arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Unrestricted -Command `". '$($__vstsAzPSScriptPath.Replace("'", "''"))'`""
    $splat = @{
        'FileName' = $powershellPath
        'Arguments' = $arguments
        'WorkingDirectory' = $input_workingDirectory
    }

    # Switch to "Continue".
    $global:ErrorActionPreference = 'Continue'
    $failed = $false
    #endregion

    #region Task execution
    # Run the script.
    Write-Host -Object '========================== Starting Command Output ==========================='
    if (-not $__vsts_input_failOnStandardError)
    {
        Invoke-VstsTool @splat
    }
    else {
        $inError = $false
        $errorLines = New-Object -TypeName System.Text.StringBuilder
        Invoke-VstsTool @splat 2>&1 |
            ForEach-Object {
                if ($_ -is [System.Management.Automation.ErrorRecord])
                {
                    # Buffer the error lines.
                    $failed = $true
                    $inError = $true
                    $null = $errorLines.AppendLine("$($_.Exception.Message)")

                    # Write to verbose to mitigate if the process hangs.
                    Write-Verbose "STDERR: $($_.Exception.Message)"
                }
                else
                {
                    # Flush the error buffer.
                    if ($inError)
                    {
                        $inError = $false
                        $message = $errorLines.ToString().Trim()
                        $null = $errorLines.Clear()
                        if ($message)
                        {
                            Write-VstsTaskError -Message $message
                        }
                    }
                    Write-Host -Object "$_"
                }
            }

        # Flush the error buffer one last time.
        if ($inError)
        {
            $inError = $false
            $message = $errorLines.ToString().Trim()
            $null = $errorLines.Clear()
            if ($message)
            {
                Write-VstsTaskError -Message $message
            }
        }
    }

    # Fail if any errors.
    if ($failed)
    {
        Write-VstsSetResult -Result 'Failed' -Message "Error detected" -DoNotThrow
    }
    #endregion
}
finally
{
    if ($__vstsAzPSInlineScriptPath -and (Test-Path -LiteralPath $__vstsAzPSInlineScriptPath) )
    {
        Remove-Item -LiteralPath $__vstsAzPSInlineScriptPath -ErrorAction 'SilentlyContinue'
    }

    Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
    Remove-EndpointSecrets
    # Stop session tracing
    Trace-VstsLeavingInvocation $MyInvocation
}