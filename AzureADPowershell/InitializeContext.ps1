[CmdletBinding()]
param
(
    [String] [Parameter(Mandatory = $true)]
    $endpoint,

    [String] [Parameter(Mandatory = $false)]
    $targetAADPs
)
try
{
    Write-Host -Object "Initialize task started"
    $endpointObject = ConvertFrom-Json $endpoint -ErrorAction SilentlyContinue -ErrorVariable oErr
    if ($oErr)
    {
        Write-Error -Message "Failed to convert endpoint data from json to object" -ErrorAction Stop
    }

    #region Variables
    $MSALScope = "https://graph.windows.net//.default"
    #endregion

    Write-Host -Object "Service Connection Endpoint type: $($endpointObject.Auth.Scheme)"
    # Get service principal id and secret
    if ( $endpointObject.Auth.Scheme -eq 'ServicePrincipal' )
    {
        Write-Host -Object "##[command]Building Credential object from service connection details"
        $psCredential = New-Object -TypeName System.Management.Automation.PSCredential(
            $endpointObject.Auth.Parameters.ServicePrincipalId,
            (ConvertTo-SecureString $endpointObject.Auth.Parameters.ServicePrincipalKey -AsPlainText -Force))
    }
    else
    {
        Write-Error -Message "This task only support ARM service principal to authenticate against Azure AD" -ErrorAction Stop
    }
    #region AAD authenticate
    Write-Host -Object "##[command]Constructing MSAL token from AAD service principal: $($psCredential.UserName) targeting Tenant: $($endpointObject.Auth.Parameters.TenantId)"
    $MSALtoken = Get-MsalToken -ClientId $($psCredential.UserName) -ClientSecret $($psCredential.Password) -TenantId $($endpointObject.Auth.Parameters.TenantId) -Scopes $MSALScope -ErrorAction Continue -ErrorVariable oErr
    if ($oErr)
    {
        Write-Error -Message "Failed get MSAL token from endpoint" -ErrorAction Stop
    }
    if($MSALtoken.AccessToken)
    {
        # Connect to AAD with MSAL token from AAD Graph
        $AADConnection = Connect-AzureAD -AadAccessToken $($MSALtoken.AccessToken) -AccountId $($psCredential.UserName) -TenantId $($endpointObject.Auth.Parameters.TenantId) -ErrorAction Continue -ErrorVariable oErr
        if ($oErr)
        {
            Write-Error -Message "Failed to authenticate against AAD" -ErrorAction Stop
        }
        if($AADConnection)
        {
            Write-Host -Object "Successfully set up AAD authentication context"
        }
        else
        {
            Write-Host -Object "Failed to set up AAD authentication context"
        }
    }
    else
    {
        Write-Error -Message "Failed to retrieve access token from AAD graph api endpoint"
    }
    #endregion
}
catch
{
    if ($_.Exception.Message)
    {
        Write-Error -Message "$($_.Exception.Message)" -ErrorAction Continue
        Write-Host -Object "##[error]$($_.Exception.Message)"
    }
    else
    {
        Write-Error -Message "$($_.Exception)" -ErrorAction Continue
        Write-Host -Object "##[error]$($_.Exception)"
    }
}
finally
{
    Write-Host -Object "Initialize task finished"
}