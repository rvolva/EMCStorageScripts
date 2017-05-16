<#

.SYNOPSIS
Create/update credential file in JSON format.

VERSION=1.3.1

.DESCRIPTION

The file can be used by other scripts to source credentials for devices access. Passwords are stored in encrypted form.

.PARAMETER DeviceName

Device DNS name or IP address

.PARAMETER User

Optional. User name to access specified device(s). Same user name can be used for all devices. The script will prompt for user name, if omitted.

.PARAMETER Password

Optional. Password

.PARAMETER CredentialFile

Credential file name 

.PARAMETER UpdateCredentialFile

Update credential file

.PARAMETER ListCredentials

List credentials in the credential file. Passwords are shown as encrypted string.

.PARAMETER ShowPassword

Show passwords in clear text. Used together with -List switch. 

.PARAMETER Help

Print help
      
.EXAMPLE

PS> ManageCredentialFile.ps1 -CredentialFile creds.json -List

.NOTES

Credential File Format:

{
    "device1":  {
                "user":  "admin1",
                "password":  "XXXXXXXXXXXXXXXXXXXX"
            },
    "device2":  {
                "user":  "admin2",
                "password":  "XXXXXXXXXXXXXXXXXXXX"
            },
    "device3":  {
                "user":  "admin3",
                "password":  "XXXXXXXXXXXXXXXXXXXXXXX"
            }
}							   


.LINK

#>

[CmdletBinding(DefaultParameterSetName="Help")]
Param
(
        [Parameter(Mandatory=$true,Position=0,ParameterSetName="Update")]
        [Parameter(ParameterSetName="List")]
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
        
        [Parameter(Mandatory=$true,ParameterSetName="Update")]
        [switch]$UpdateCredentialFile=$True,
        
        [Parameter(Mandatory=$true,ParameterSetName="List")]
        [switch]$ListCredentials,

        [Parameter(ParameterSetName="List")]
        [switch]$ShowPassword,


        [Parameter(ParameterSetName="Help")]
        [switch]$help

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

    function listCredentials {
        
        param(
            [string]$CredFile,
            [string[]]$DeviceName,
            [switch]$ShowPassword
        )

        $creds=readCredentialFile $CredFile

        $deviceCredentials=@()

        if( $DeviceName ) {
        
            $devList = $DeviceName

        } else {

            $devList = ($creds| Get-Member -MemberType NoteProperty).Name    

        }

        foreach( $dev in $devList ) {
            
            if( $ShowPassword ) {
                
                try {
                    $secureStringPassword = $creds.$dev.password | ConvertTo-SecureString
                    $credObj = New-Object -type pscredential -args $creds.$dev.user,$secureStringPassword
                    $password = $credObj.GetNetworkCredential().Password
                } 
                
                catch  {

                    $password="ERROR: failed to decrypt the secure string"
                }

            } else {
                
                $password=$creds.$dev.password
            
            }

            $deviceCredential=[ordered]@{Device=$dev;User=$creds.$dev.user;Password=$password }    
            $deviceCredObj=New-Object -TypeName psobject -Property $deviceCredential
            $deviceCredentials+=$deviceCredObj
        }

        $deviceCredentials 
    }

    function updateCredentialFile( $devList, $credFile, $commandLineUser, $commandLinePassword ) {

        if( Test-Path $credFile ) {
            $creds=readCredentialFile $credFile
        } else {
            $creds=New-Object -TypeName psobject
        }

        foreach( $dev in $devList ) {

            if( $commandLineUser -eq "" -or $commandLinePassword -eq "" ) {
        
                $secureCreds=Get-Credential -UserName $commandLineUser -Message "Credentials for $dev"

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
            
                $credObject=New-Object -TypeName PSObject -Property @{user=$user;password=$password}

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

    switch ( $PsCmdlet.ParameterSetName )
    {
        'Help' { get-help $script:MyInvocation.MyCommand.Definition }

        'List' {    
                    $listFuncParams=@{ CredFile = $CredentialFile; ShowPassword=$ShowPassword }
            
                    if( $DeviceName ) {
                        
                        $listFuncParams.DeviceName=$DeviceName
                    
                    }
                
                    listCredentials @listFuncParams
               }  

        'Update' { UpdateCredentialFile $DeviceName $CredentialFile $User $Password }

    }

}

