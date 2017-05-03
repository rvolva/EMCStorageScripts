<#

.SYNOPSIS
VNX for File Health Check Report

.DESCRIPTION
The script generates VNX for File health check report.

.PARAMETER ControlStation

IP address or DNS name of a control station(s)

.PARAMETER AllControlStations

Run the script against all control stations in the credential file.

.PARAMETER User

VNX control station user name

.PARAMETER Password

VNX Control Station password 

Will prompt for a password, if ommited and there is no password in the credential file or credintial file is not specified

.PARAMETER SSHKey

SSH private key file

.PARAMETER CredentialFile

Json file with logon credentials. Password must be stored as secure strings. For the script to be able to decode the passwords, the credential file must be created using the same Windows account.

.PARAMETER -HealthCheck

Define type of health check to run


.PARAMETER Help

Print help

.EXAMPLE
vnx_file_health_check.ps1 -ControlStation cs1,cs2

.EXAMPLE
vnx_file_health_check.ps1 -Name cs1,cs2 -HealthCheck Replication

.EXAMPLE
vnx_file_health_check.ps1 -ControlStation cs1,cs2 -CredentialFile credentials.json -HealthCheck Replication

.EXAMPLE
vnx_file_health_check.ps1 -cs1,cs2 -SSHKey id_rsa -HealthCheck Replication


.NOTES

Credential File Format:

{
    "cs1":  {
                "user":  "nasadmin1",
                "password":  "xx1"
            },
    "cs2":  {
                "user":  "nasadmin2",
                "password":  "pass2"
            },
    "cs5":  {
                "user":  "nasadmin5",
                "password":  "pass5"
            }
}							   


.LINK

#>

[CmdletBinding(DefaultParameterSetName="Help")]
Param(

    [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0,ParameterSetName="CredentialFile")]
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0,ParameterSetName="UserPassword")]
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0,ParameterSetName="SSHKey")]
    [Alias("Name")]
    [string[]]$ControlStation,

    [Parameter(Mandatory=$true,Position=0,ParameterSetName="AllControlStations")]
    [Alias("All")]
    [switch]$AllControlStations,

    [Parameter(Mandatory=$true,ParameterSetName="UserPassword")]
    [Parameter(Mandatory=$true,ParameterSetName="SSHKey")]
    [string]$User,

    [Parameter(ParameterSetName="UserPassword")]
    [string]$Password,

    [Parameter(Mandatory=$true,ParameterSetName="CredentialFile")]
    [Parameter(Mandatory=$true,ParameterSetName="AllControlStations")]
    [Alias("File")]
    [string]$CredentialFile,

    [Parameter(Mandatory=$true,ParameterSetName="SSHKey")]
    [string]$SSHKey,

    [ValidateSet(“Replication”)]
    [string[]]$HealthCheck="Replication",

    [Parameter(ParameterSetName="Help")]
    [switch]$Help

)



Begin {

    $SCRIPT_VERSION="1.1"
    $ControlStationList=@()


    function printReportHeader {
        "VNX FILE HEALTH CHECK"
        "====================="
        "Script Version: $SCRIPT_VERSION"
        "Date: {0}" -f (Get-Date)
        ""
    }

    function readCredentialFile( $credentialFile ) {

        try
        {
            cat -raw $credentialFile  -ErrorAction stop  | convertfrom-json
        }
    
        catch {
            Write-Host "Couldn't open credential file $credentialFile"
            exit 1
        }
    }

    if( $PsCmdlet.ParameterSetName -eq "Help" ) {
        get-help $script:MyInvocation.MyCommand.Definition
        exit 1
    }
    
    if( $CredentialFile ) {
        $credentials=readCredentialFile $CredentialFile
    }

    if( $PsCmdlet.ParameterSetName -eq "UserPassword" -and ! $Password ) {
        $Password = Read-Host "$User password: "
    } 
    
    if( $AllControlStations ) {

        foreach( $cs in ( $credentials | Get-Member -MemberType NoteProperty).Name ) {
            $ControlStationList+=$cs
        }
    }

    
    printReportHeader

}

Process {
    $script:ControlStationList+=$ControlStation

}

End {
    
    $healthCheckFunctions=@{
        Replication="runReplicationCheck"
    }

    function openSSHConnection ( $cs, $user, $password="default", $sshkey ) {
        
        if( $password -eq "" ) { $password="default" }

        $securePassword=ConvertTo-SecureString -AsPlainText $password -Force
        $psCred=New-Object -TypeName pscredential ($user,$securePassword)

        if( $sshkey ) {
            New-SSHSession -ComputerName $cs -AcceptKey -Credential $psCred -KeyFile $sshkey 
        } else {
            New-SSHSession -ComputerName $cs -AcceptKey -Credential $psCred
        }
    }
    
    function runReplicationCheck ( $sshSession ) {

        $cmd="/nas/bin/nas_replicate -report -fields name,lastSyncTime,sourceStatus,destinationStatus,networkStatus,prevTransferRateKB,maxTimeOutOfSync"
        #$cmd="/nas/bin/nas_replicate -list"

        $invokeOut=Invoke-SSHCommand -SessionId $SSHSession.SessionID -Command $cmd

        if( $invokeOut.ExitStatus -eq 0 ) {
            
            $format=@(
                @{name="Replication Name";e={$_.name}},
                @{name="Src Status";e={ $_.sourceStatus -replace "^.*: ","" -replace "Replication session state is not accessible.","N/A" };a="center" },
                @{name="Dest Status";e={$_.destinationStatus -replace "^.*: ","" -replace "Replication session state is not accessible.","N/A"};a="center"},
                @{name="Network Status";e={$_.networkStatus -replace "^.*: ",""};a="center" },
                @{name="Max Out of Sync Time(Min)";e={$_.maxTimeOutOfSync};a="center" },
                @{name="Last Sync Time";e={$_.lastSyncTime} },
                @{name="Last Sync Transfer Rate KB/s";e={ "{0:N0}" -f [int]$_.prevTransferRateKB}; a="right" }
            )

            $replicationItems=$invokeOut.Output | ConvertFrom-Csv 
            $replicationItems | ft -auto $format
                
            

        } else {
            "Command {0} failed, SSH session exit code {1}" -f $healthCheckCommans.$healthCheckType, $invokeOut.ExitStatus
        }
    }

    foreach( $cs in $ControlStationList ) {
        
        if( (openSSHConnection $cs $user $Password $SSHKey) -eq $null ) {

            "ERROR: connection to $cs failed"

            $ControlStationList=$ControlStationList -notlike $cs

        }

    }

    $SSHSessions=Get-SSHSession

    foreach( $healthCheckType in $healthCheck ) {

        foreach( $cs in $ControlStationList ) {

            "-- $cs $healthCheckType -----------------------------"
            ""

            $SSHSession = $SSHSessions | where { $_.Host -eq $cs }

            $healthCheckFunction='{0} $SSHSession' -f $healthCheckFunctions.$healthCheckType

            invoke-expression $healthCheckFunction

            ""
        }
    }

    foreach( $SSHSession in $SSHSessions ) {
        #"removing SSH session " + $SSHSession.SessionId
        [void](Remove-SSHSession $SSHSessions)
    }

}