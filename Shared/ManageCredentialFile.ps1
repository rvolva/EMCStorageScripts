<#

.SYNOPSIS
This script allows to create and update credential file in JSON format. The file can be used by
other scripts to source credentials used to access devices.

.DESCRIPTION

Parameter Set "Update"

-DeviceName <dev1>[,<dev2>] device DNS name or IP address
-User <user name>			optional, user name to access specified device(s). Same user name can be used for all devices 
-Password <password>		optional, password 
-CredentialFile <file>      credential file name 
-UpdateCredentialFile       update credential file
       
Parameter Set "List"
-ListCredentials            list credentials in the credential file
-CredentialFile <file>      credential file name

Parameter Set "Help"
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


.NOTES

.LINK

#>

[CmdletBinding(DefaultParameterSetName="Help")]
Param
(
        [Parameter(Mandatory=$true,Position=0,ParameterSetName="Update")]
        [Alias("Name")]
        [string[]]$DeviceName,

	    [Parameter(ParameterSetName="Update")]
        [string]$User,

        [Parameter(ParameterSetName="Update")]
	    [string]$Password,

        [Parameter(Mandatory=$true,ParameterSetName="Update")]
        [Parameter(Mandatory=$true,ParameterSetName="List")]
        [Alias("File")]
        [string]$CredentialFile,

        [Parameter(ParameterSetName="Update")]
        [switch]$UpdateCredentialFile=$True,

        [Parameter(Mandatory=$true,ParameterSetName="List")]
        [switch]$ListCredentials,

        [Parameter(ParameterSetName="Help")]
        [switch]$help,

        [Parameter(ValueFromRemainingArguments=$true)] 
        $vars

)

Begin {
    $SCRIPT_VERSION="1.0"
}

Process
{

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

    function UpdateCredentialFile {

        param(
            [string[]]$DeviceName,
	        [string]$User,
	        [string]$Password,
            [string]$CredentialFile,
            [switch]$UpdateCredentialFile,
            [switch]$ListCredentials,
            [switch]$help
        )

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

    if( $vars ) {
        "ERROR: unknown argument $vars"
        exit 1
    }

    switch ( $PsCmdlet.ParameterSetName )
    {
        'Help' { get-help $script:MyInvocation.MyCommand.Definition }
        'List' { "List" }
        'Update' { "Update" }
    }

}

