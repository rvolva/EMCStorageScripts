<#

.SYNOPSIS
VNX for File Health Check Report

.DESCRIPTION
The script generates VNX for File health check report.

Parameters:

-ControlStation <VNX CS IP>[,<IP>]  	VNX Control Station IP addresses or host names, if omitted the script will run against all control stations in the credential file
-User <user name>			VNX control station user name, required if credintial file is not provided
-Password <password>		password, will prompt for password, if ommited and there is no password in the credential file or credintial file is not specified
-CredentialFile <file>      json file with logon credentials (passwords are encrypted), creates the file if it doesn't exist
-UpdateCredentialFile       saves credentials  into the credfile
-Help                       print help

Credential File Format:

[
    { 
      "cs_name": "cs1",
      "user": "nasadmin1",
      "password": "xx1"
    },
    { 
      "cs_name":    "cs2",
      "user": "nasadmin2",
      "password": "xx2"
    }
]
							   
.EXAMPLE

vnx_file_replication_status.ps1 -ip X.X.X.X,X.X.X.X
vnx_file_replication_status.ps1 -credfile cs_cred_file.json -all_cs
vnx_file_replication_status.ps1 -credfile cs_cred_file.json -ip vnx01_cs0 -user nasadmin -update_cred_file

.NOTES

.LINK

#>

param(
    [string[]]$ControlStation,
	[string]$User,
	[string]$Password,
    [string]$CredentialFile,
    [string]$UpdateCredentialFile,
    [switch]$help
)

$SCRIPT_VERSION="1.0"

#$ControlStationList=@()
$ControlStationCredentials=[ordered]@{}
$ControlStationDetails=@{}

#$credentials=if( $user -ne "" -and $password -ne "" ) { "-user $user -password $password -scope 0" }



function processParameters {
    
    if( ($script:ControlStation -eq $null -and $script:CredentialFile -eq "" ) -or $script:help ) {
        "vnx_file_health_check.ps1 version $SCRIPT_VERSION"
        ""
        "Usage:"
        ""
         "vnx_file_health_check.ps1 -ControlStation <cs1>,[<cs2>] -User <user name> -Password <password> -CredentialFile <file> -UpdateCredentialFile -Help"
        exit
    }
}

function printReportHeader {
    "Version $SCRIPT_VERSION"
}

function readCredentialFile( $credFile ) {

    if( $credFile -eq "" ) {
        return
    }


    try
    {
        $creds_array=(cat $credFile  -ErrorAction stop) -join "`n"  | convertfrom-json
    }
    
    catch {
        Write-Host "Couldn't open file $credfile"
        exit 1
    }


    $cred_dictionary=[ordered]@{}

    foreach( $cred in $creds_array ) {
        $cred_dictionary.add( $cred.cs_name, @{ user=$cred.user;password=$cred.password } )
    }

    $cred_dictionary

}

processParameters


$credentials=readCredentialFile $CredentialFile

$credentials.cs2

printReportHeader


<#foreach( $cs in $ControlStation ) {
        $cs
}#>


