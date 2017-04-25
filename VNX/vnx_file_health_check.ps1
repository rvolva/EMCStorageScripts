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
    { "cs1" : { "user": "nasadmin",
                "password": ""
              },
    { "cs2" : { "user": "nasadmin",
                "password": ""
              }
]
							   
.EXAMPLE

vnx_file_replication_status.ps1 -ip X.X.X.X,X.X.X.X
vnx_file_replication_status.ps1 -credfile cs_cred_file.json -all_cs
vnx_file_replication_status.ps1 -credfile cs_cred_file.json -ip vnx01_cs0 -user nasadmin -update_cred_file

.NOTES

.LINK

#>

[CmdletBinding()] 
param(
    [string[]]$ControlStation,
	[string]$User,
	[string]$Password,
    [string]$CredentialFile,
    [string]$UpdateCredentialFile,
    [switch]$help
)

BEGIN {
    $SCRIPT_VERSION="1.0"

    $ControlStationList=@()
    $ControlStationCredentials=[ordered]@{}
    $ControlStationDetails=@{}



    $credentials=if( $user -ne "" -and $password -ne "" ) { "-user $user -password $password -scope 0" }
}


PROCESS {

    foreach( $cs in $ControlStation ) {
        $SCRIPT_VERSION
        $cs
    }

}


