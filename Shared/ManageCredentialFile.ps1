<#

.SYNOPSIS
Create/update credential file in JSON format.

VERSION=1.2

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

List credentials in the credential file

.PARAMETER Help

Print help
      
.EXAMPLE


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
        [Parameter(Mandatory=$true,Position=0,ParameterSetName="Show")]
        [Alias("Name")]
        [string[]]$DeviceName,

	    [Parameter(ParameterSetName="Update")]
        [string]$User,

        [Parameter(ParameterSetName="Update")]
	    [string]$Password,

        [Parameter(Mandatory=$true,ParameterSetName="Update")]
        [Parameter(Mandatory=$true,ParameterSetName="List")]
        [Parameter(Mandatory=$true,ParameterSetName="Show")]
        [Alias("File")]
        [string]$CredentialFile,
        
        [Parameter(Mandatory=$true,ParameterSetName="Update")]
        [switch]$UpdateCredentialFile=$True,
        
        [Parameter(Mandatory=$true,ParameterSetName="List")]
        [switch]$ListCredentials,

        [Parameter(Mandatory=$true,ParameterSetName="Show")]
        [switch]$Show,


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

    function listCredentials( $credFile ) {

        $creds=readCredentialFile $credFile

        $deviceCredentials=@()

        foreach( $dev in ($creds | Get-Member -MemberType NoteProperty).Name ) {

            $deviceCredential=[ordered]@{Device=$dev;User=$creds.$dev.user;Password=$creds.$dev.password}    
            
            $deviceCredObj=New-Object -TypeName psobject -Property $deviceCredential
            
            $deviceCredentials+=$deviceCredObj
        }

        $deviceCredentials 
    }

    function UpdateCredentialFile( $devList, $credFile, $commandLineUser, $commandLinePassword ) {

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

    function showCredential( $devList, $credFile ) {

        $creds=readCredentialFile $credFile

        foreach( $dev in $devList ) {

            if( $creds.$dev ) {

                $secureStringPassword=$creds.$dev.password | ConvertTo-SecureString

                $credObj = New-Object -type pscredential -args $creds.$dev.user,$secureStringPassword

                "User: {0}" -f $creds.$dev.user
                "Password: {0}" -f $credObj.GetNetworkCredential().Password


            } else {
                "no such device: {0}" -f $dev
            }
        }
    }


    switch ( $PsCmdlet.ParameterSetName )
    {
        'Help' { get-help $script:MyInvocation.MyCommand.Definition }

        'List' { listCredentials $CredentialFile }

        'Update' { UpdateCredentialFile $DeviceName $CredentialFile $User $Password }

        "Show"  { showCredential $DeviceName $CredentialFile  }
    }

}

