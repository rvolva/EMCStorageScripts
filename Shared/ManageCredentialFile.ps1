<#

.SYNOPSIS
This script allows to create and update credential file in JSON format. The file can be used by
other scripts to source credentials for devices access. Passwords are stored in encrypted form.

VERSION=1.0

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
}

Process
{

    function readCredentialFile( $credFile ) {

        try
        {
            cat -raw $credFile  -ErrorAction stop  | convertfrom-json
        }
    
        catch {
            Write-Host "Couldn't open credential file $credFile"
            exit 1
        }

    }

    function listCredentials( $credFile ) {

        $creds=readCredentialFile $credFile

        $deviceCredentials=@()

        foreach( $dev in ($creds | Get-Member -MemberType NoteProperty).Name ) {
            $deviceCredential=[ordered]@{Device=$dev;User=$creds.$dev.user;Password=$creds.$dev.password}    
            
            $deviceCredObj=New-Object -TypeName psobject -Property $deviceCredential
            
            $deviceCredentials+=$deviceCredObj
        }

        $deviceCredentials | ft -AutoSize
    }

    function UpdateCredentialFile( $devList, $credFile, $commandLineUser, $commandLinePassword ) {

        $creds=readCredentialFile $credFile

        foreach( $dev in $devList ) {

            if( $commandLineUser -eq "" -or $commandLinePassword -eq "" ) {
        
                $secureCreds=Get-Credential -UserName $commandLineUser -Message "Credentials for $dev" # what if cancelled?

                if( $secureCreds -eq $null ) {
                    continue
                }
                
                $user=$secureCreds.UserName
                $password=$secureCreds.Password | ConvertFrom-SecureString 

            } else {

                $user=$commandLineUser
                $password=$commandLinePassword | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString
        
            }

            if( $creds.$dev -eq $null ) {
            
                $cred=@{user=$user;password=$password}
                $credObject=New-Object -TypeName PSObject -Property $cred

                $creds | Add-Member -NotePropertyName $dev -NotePropertyValue $credObject
            
            } else {
            
                    $creds.$dev.user=$user
                    $creds.$dev.password=$password
            
            }

            try
            {
                ConvertTo-Json $creds | out-file -Encoding ascii -FilePath $credFile
            }
    
            catch {
                Write-Host "Couldn't update credential file $credFile"
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

        'List' { listCredentials $CredentialFile }

        'Update' { UpdateCredentialFile $DeviceName $CredentialFile $User $Password }
    }

}

