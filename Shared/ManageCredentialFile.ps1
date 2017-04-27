<#
    This module allows to create and update credintial file in JSON format. The file can be used by
    other scripts to source credentials used to access devices. 

    Credentials are stored in the following JSON format:

    {
    "DeviceName1":  {
                "user":  "device1_user",
                "password":  "XXXXXXXXXXXXXXXXXXX"
            },
    "DeviceName2":  {
                "user":  "device2_user",
                "password":  "XXXXXXXXXXXXXXXXXXX"
            },
    "DeviceName3":  {
                "user":  "device3_user",
                "password":  "XXXXXXXXXXXXXXXXXXX"
            }
    }

    where "unitx" is a DNS name or IP of a managed array, switch, etc.
     
#>

function _readCredentialFile( $credFile ) {

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

