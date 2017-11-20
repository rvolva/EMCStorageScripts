<#

.SYNOPSIS

EMC VPLEX Functions

.DESCRIPTION
EMC VPLEX Functions

VERSION: 1.0

.EXAMPLE

PS> run-vplexRESTCmd -ip 192.168.5.5 -HTTPMethod GET -Username service -Cmd "/clusters"

.NOTES


.LINK

#>

function disableHTTPSCerticateValidation {

        if( -not ("TrustAllCertsPolicy" -as [type])  ) {

            Add-type @"
                using System.Net;
                using System.Security.Cryptography.X509Certificates;

                public class TrustAllCertsPolicy : ICertificatePolicy {
                    public bool CheckValidationResult (ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {
                        return true;
                    }
                }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

        }
}

function run-vplexRESTCmd {
      param(
            [string]  $IP,
            [string]  $HTTPMethod="GET",
            [string]  $credfile,
            [string]  $Username,
            [string]  $Password,
            [string]  $Cmd,
            [switch]  $help

        )

        if( -not $IP -or -not $Cmd -or $help ) {
            "Usage: run-vplexRESTCmd -ip <vplex IP> [-HTTPMethod GET|POST|PUT] [-Username <username>] [-Password <password>] -Cmd <vplex command>"
            return
        } 

        disableHTTPSCerticateValidation

        if( $credfile ) {
            
            try {
                $creds=cat -raw $credfile | ConvertFrom-Json
                $username=$creds.$ip.Username
                $password=$creds.$ip.password
            }
            catch {
                write-error "Error reading credential file $credfilename"
                return
            }                
        }

        if( -not $Username -or -not $Password) {

            $cred=Get-Credential -username $Username -Message "Credentials for VPLEX $IP"
            $Username=$cred.UserName
            
            $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cred.password)
            $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        }

        $BackgroundCmdCheckIntSec=30
        $MaxBackgroundCmdCheckAttempts=10

        $httpHeader=@{Username=$Username;Password=$Password;Accept="application/json;format=1;prettyprint=1" }
        $vplexCmd=($Cmd -split "\s+")[0]
        $vplexCmdArgs=$Cmd -replace "^\S+",""

        $vplexURI="https://$IP/vplex/$vplexCmd"
        $httpBody=convertto-json @{ args=$vplexCmdArgs }

        try {

            if( $HTTPMethod -eq "Post" ) {
                $webReply=Invoke-WebRequest -uri $vplexURI -Headers $httpHeader -Method $HTTPMethod -Body $httpBody -SessionVariable WebSessionID

            } else {
                $webReply=Invoke-WebRequest -uri $vplexURI -Headers $httpHeader -Method $HTTPMethod -SessionVariable WebSessionID
            }


        } 
        
        catch [System.Net.WebException] {
    
            $errMsg=$_.Exception.toString()
            Write-Error $errMSg

            return
        }


        if( $webReply.StatusCode -eq 202 ) {

            $cmdResult=$webreply.Headers.Location


            foreach( $i in 0..$MaxBackgroundCmdCheckAttempts ) {

                Write-Progress -Activity  "Executing `"$vplexCmd $vplexCmdArgs`" on $IP" -PercentComplete ($i*100/$MaxBackgroundCmdCheckAttempts) -Status "Please wait."
        
                Start-Sleep $BackgroundCmdCheckIntSec

                try {
                    $webReply=Invoke-WebRequest -uri $cmdResult -WebSession $WebSessionID

                } catch [System.Net.WebException] {
                    if( [int]$_.Exception.Response.StatusCode -ne 517 ) {
                        $errMsg=$_.Exception.toString()
                        Write-Error $errMSg
                        return
                    } 
                }

                if( $webReply.StatusCode -eq 200 ) {
                    break
                }
            }

            Write-Progress -Activity "Executing `"$vplexCmd $vplexCmdArgs`" on $IP" -Completed -Status "Completed."
        }


        if( $webReply.StatusCode -eq 200 ) {
        
            [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")        
            $jsonserial= New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer 
            $jsonserial.MaxJsonLength  = 20MB
            $jsonserial.DeserializeObject( $webReply.content )   

            return $jsonserial

            <#
            $webReplyContent=convertfrom-json $webReply.content

            if( $webReplyContent.response.context -ne $null ) {
                $webReplyContent.response.context
            }

            if( $webReplyContent.response.'custom-data' -ne $null ) {
                $webReplyContent.response.'custom-data' -replace "\033\[\d+m",""
            }#>
        } else {
        
            write-error "No response from VPLEX"

        }
}

function get-vplexstorageviews {

      param(
            [string]  $IP,
            [string]  $Username,
            [string]  $Password
            
        )

        if( -not $IP ) {
            "Usage: get-vplexstorageviews -ip <vplex IP> [-Username <username>] [-Password <password>]"
            return
        } 

        run-vplexRESTCmd -ip $ip -Cmd "/clusters/*/exports/storage-views/*"
}

function get-vplexvirtualvolumes {

      param(
            [string]  $IP,
            [string]  $Username,
            [string]  $Password
            
        )

        if( -not $IP ) {
            "Usage: get-vplexvirtualvolumes -ip <vplex IP> [-Username <username>] [-Password <password>]"
            return
        } 

        return run-vplexRESTCmd -ip $ip -Cmd "/clusters/*/virtual-volumes/*"
}

function get-vplexstoragevolumes {

      param(
            [string]  $IP,
            [string]  $Username,
            [string]  $Password
            
        )

        if( -not $IP ) {
            "Usage: get-vplexvirtualvolumes -ip <vplex IP> [-Username <username>] [-Password <password>]"
            return
        } 

        return run-vplexRESTCmd -ip $ip -Cmd "/clusters/*/storage-elements/storage-volumes/*"
}

