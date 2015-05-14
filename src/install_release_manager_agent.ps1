#Powershell 2.0

# Stop and fail script when a command fails.
$errorActionPreference = "Stop"

# load library functions
$rsLibDstDirPath = "$env:rs_sandbox_home\RightScript\lib"
. "$rsLibDstDirPath\tools\PsOutput.ps1"
. "$rsLibDstDirPath\tools\ResolveError.ps1"
. "$rsLibDstDirPath\win\Version.ps1"

#The Registry location for the ReleaseManagement Agent
$x64 = "HKLM:\Software\Wow6432Node\Microsoft\ReleaseManagement\12.0\Deployer\Configuration"

#Release Manager Agent Service properties
$UserName = $env:RM_SERVICE_NAME
$Password = $env:RM_SERVICE_PASSWORD
$Service = "Microsoft Deployment Agent"

Try
{
    # detects if server OS is 64Bit or 32Bit
    # Details http://msdn.microsoft.com/en-us/library/system.intptr.size.aspx
    if (Is32bit)
    {
        Write-Host "32 bit operating system"
        $rma_path = join-path $env:programfiles "Microsoft Visual Studio 12.0"
    }
    else
    {
        Write-Host "64 bit operating system"
        $rma_path = join-path ${env:programfiles(x86)} "Microsoft Visual Studio 12.0"
    }

    if (test-path $rma_path)
    {
        Write-Output "Release manager agent is already installed. Skipping installation."
        exit 0
    }

    Write-Host "Installing Release Manager agent to $rma_path"

    $rma_binary = "release_manager_agent_x86_x64_3578520.exe"
    cd "$env:RS_ATTACH_DIR"
    cmd /c $rma_binary /Silent /NoRestart /Full

    #Permanently update windows Path
    if (Test-Path $rma_path) {
        [environment]::SetEnvironmentvariable("PATH", $env:PATH+";"+$rma_path, "Machine")
    }
    Else
    {
        throw "Failed to install Release manager agent. Aborting."
    }

    Copy-Item "$env:RS_ATTACH_DIR\Microsoft.TeamFoundation.Release.Data.dll.config.new" -Destination "$rma_path\Release` Management\bin\Microsoft.TeamFoundation.Release.Data.dll.config" -Force
    
    #We're going to see if the ConnectTo key already exists, and create it if it doesn't.
    if (!(Test-Path $x64)){
        New-Item $x64
    }
    Else
    {
        Write-Host "$x64 exists"
    }

    #Creating registry entry
    New-Item -Path HKCU:\Software\Wow6432Node\Microsoft\ReleaseManagement\12.0\Deployer -Name Configuration -Force

    #Setting the registry values
    New-ItemProperty -Path $x64 -Name Username -PropertyType String -Value $env:RMUSERNAME
    New-ItemProperty -Path $x64 -Name ReleaseServerUrl -PropertyType String -Value $env:RMURL
    
    #Updating Service Properties and Starting the Service
    $svcD=gwmi win32_service -filter "name='$Service'"
    $StopStatus = $svcD.StopService()
    if ($StopStatus.ReturnValue -eq "0") # validating status - http://msdn.microsoft.com/en-us/library/aa393673(v=vs.85).aspx
        {Write-Host "Service Stopped Successfully"}
    $ChangeStatus = sc.exe config $Service obj=$Username password=$Password
    if ($ChangeStatus.ReturnValue -eq "0")
        {Write-Host "Sucessfully Changed User Name"}
    $StartStatus = $svcD.StartService()
    if ($ChangeStatus.ReturnValue -eq "0")
        {Write-Host "Service Started Successfully"}
        
}
Catch
{
    ResolveError
    exit 1
}

