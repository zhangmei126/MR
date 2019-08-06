#Requires -RunAsAdministrator

<#
.SYNOPSIS 
    Companion script to run MixedRealitySpatialDataPackager.exe that automatically detects package family name for an app, user SID for a username, and locks/unlocks the map

.DESCRIPTION
    Get-help MRSpatialPackagerHelperScript.ps1 -Detailed to see full details

.PARAMETER UserName 
    Target username, will return a list of users if a unique match is not found
        
.PARAMETER AppName
    On export: The spatial anchors from the app you are interested in
    On import: The app that you want to import the spatial anchors for
    Returns a list of apps if a unique app is not found
    
.PARAMETER Mode
    import or export

.PARAMETER MapxPath
    On export: Directory to export your mapx files
    On import: Directory where import mapx are stored

.PARAMETER LockMap
    Specifies whether or not to lock the map

.PARAMETER BinPath
    Path to MixedRealitySpatialDataPackager.exe, default value is current directory

.EXAMPLE
    MRSpatialPackagerHelperScript.ps1 -AppName holoshell -UserName admin -Mode import -MapxPath C:\documents\ -Binpath C:\downloads\packager\ -LockMap 1
#>

Param
(       
    [Parameter(Mandatory=$true)]
        [string] $AppName,
    
    [Parameter(Mandatory=$true)]
        [string] $UserName,

    [Parameter(Mandatory=$true)][ValidateSet("import", "export", IgnoreCase = $true)]
        [string] $Mode,

    [Parameter(Mandatory=$true)]
        [string] $MapxPath,

    [ValidateSet(0,1)] #the functionality of this flag requires an updated driver with map locking 
        [int] $LockMap = 0,

    [string] $BinPath = (Get-Item -Path ".\").FullName    
)


#We need to force powershell to run in 64-bit mode to allow the script to function properly.
if([Environment]::Is64BitOperatingSystem)
{
    if (![Environment]::Is64BitProcess )
    {
        write-warning "x86 Powershell detected, calling this script in x64 Powershell instead..."
        $psPath = "$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe"
        $scriptArgs = @($MyInvocation.MyCommand.Path)
        $p = $MyInvocation.BoundParameters
        $scriptArgs += ( $p.Keys | % { ('-' + $_), $p.Item($_) } )
        Start-Process -NoNewWindow -FilePath $psPath -ArgumentList $scriptArgs -Wait
        ""
        exit $lastexitcode
    }
}
""

try
{
    $pk = Get-AppxPackage -Name "*$AppName*"

    if($pk.Count -eq 1)
    {
        $appID = $pk.PackageFamilyName   
    }
    elseif ($pk.Count -gt 1)
    {
        "Which app package would you like to use?"
        $counter = 0
        foreach($app in $pk)
        {
            $name = $app.Name
            Write-Output "$counter. $name"
            $counter++
        }

        $value = Read-Host 'Input a value'
        $appID = $pk[$value].PackageFamilyName
        ""
    }
    else
    {
        "Could not find an app with that name installed on this PC"
        return
    }

    "Package Family Name for " + $AppName + ": " + $appID

}
catch
{
    Throw "Invalid app name"
}

try
{
    try
    {
        $objUser = Get-WmiObject -Class Win32_UserAccount -Filter "Name='$UserName'"
        if($objUser.Name.Count -eq 1)
        {
            $strSID = $objUser.SID
        }    
        else
        {
            $objUser = Get-WmiObject -Class Win32_UserAccount -Filter  "LocalAccount='True'"
            "Which user would you like to use?"
            $counter = 0
            foreach($user in $objUser)
            {
                $name = $user.Name
                Write-Output "$counter. $name"
                $counter++
            }

            $value = Read-Host 'Input a value'
            $UserName = $objUser[$value].Name
            $strSID = $objUser[$value].SID
            ""
        }
        "User SID for " + $UserName + ": " + $strSID
    }        
    catch
    {
        # IOT doesn't have Get-WmiObject
        "Looking up SID for " + $UserName
        $UserObject = [System.Security.Principal.NTAccount]::new($UserName)
        $strSID = $UserObject.Translate([System.Security.Principal.SecurityIdentifier])
        "Found SID " + $strSID 
    }
}
catch
{
    Throw "Invalid username"
}

$args = "$Mode $MapXPath $AppID "
if($Mode -eq "import")
{
    $args += $strSid
}

$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Spectrum\Extensions\Head Tracker"
$name = "LockMap"

try
{
    if(!(Test-Path $registryPath))
    {
        New-Item -Path $registryPath -Force | Out-Null
        New-ItemProperty -Path $registryPath -Name $name -Value $LockMap -PropertyType DWORD -Force | Out-Null
    }
    else
    {
        Set-ItemProperty -Path $registryPath -Name $name -Value $LockMap -Force | Out-Null
    }
    
    $lockMapSetValue = Get-ItemProperty -Path $registryPath
    
    if ($lockMapSetValue.LockMap -eq $LockMap)
    {
        "Lock map value succesfully set to $LockMap"
    }
    else
    {
        Throw "Attempt to set map lock status failed"
    }
}
catch
{
    Throw "Attempt to set map lock status failed"
}


""            
Write-Host "Running: $BinPath\MixedRealitySpatialDataPackager.exe $args" -foregroundcolor DarkGreen -backgroundcolor black
""

$proc = Start-Process `
    -FilePath "$BinPath\MixedRealitySpatialDataPackager.exe" `
    -ArgumentList $args `
    -NoNewWindow `
    -PassThru `
    -Wait