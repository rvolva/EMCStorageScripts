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
    [switch]$UpdateCredentialFile,
    [switch]$help
)

$SCRIPT_VERSION="1.0"

#$ControlStationList=@()
$ControlStationCredentials=[ordered]@{}
$ControlStationDetails=@{}

#$credentials=if( $user -ne "" -and $password -ne "" ) { "-user $user -password $password -scope 0" }



function validateParameters {
    
    if( ($script:ControlStation -eq $null -and $script:CredentialFile -eq "" ) -or $script:help ) {
        "vnx_file_health_check.ps1 version $SCRIPT_VERSION"
        ""
        "Usage:"
        ""
         "vnx_file_health_check.ps1 -ControlStation <cs1>,[<cs2>] -User <user name> -Password <password> -CredentialFile <file> -UpdateCredentialFile -Help"
        exit 1
    }

    if( $script:UpdateCredentialFile -and $script:CredentialFile -eq "" ) {
        "ERROR: must provide credential file name with -UpdateCredentialFile option"
         exit 1
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
        cat -raw $credFile  -ErrorAction stop  | convertfrom-json
    }
    
    catch {
        if( $script:UpdateCredentialFile ) {
            New-Object -TypeName psobject
        }
        else {
            Write-Host "Couldn't open file $credfile"
            exit 1
        }
    }
}

function updateCredentialFile( $creds ) {

    foreach( $cs in $ControlStation ) {

        if( $script:User -eq "" -or $script:Password -eq "" ) {
        
            $secureCreds=Get-Credential -UserName $script:User -Message "Credentials for $cs" # what if cancelled?
            $user=$secureCreds.UserName
            $password=$secureCreds.Password | ConvertFrom-SecureString 
        
        } else {
        
            $user=$script:User
            $password=$script:Password | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString
        
        }

        if( $script:credentials.$cs -eq $null ) {
            
            $creds=@{user=$user;password=$password}
            $credObject=New-Object -TypeName PSObject -Property $creds

            $script:credentials | Add-Member -NotePropertyName $cs -NotePropertyValue $credObject
            
        } else {
            
                $script:credentials.$cs.user=$user
                $script:credentials.$cs.password=$password
            
        }

        try
        {
            ConvertTo-Json $script:credentials | out-file -Encoding ascii -FilePath $script:CredentialFile
        }
    
        catch {
            Write-Host "Couldn't update credential file $script:CredentialFile"
        }
    }
}


validateParameters


$credentials=readCredentialFile $CredentialFile

if( $UpdateCredentialFile ) {
    updateCredentialFile $credentials
}

printReportHeader



foreach( $cs in $ControlStation ) {

        if( $UpdateCredentialFile ) {

 

        } else {
            # run health check
        }

}


