<#

.SYNOPSIS
EMC VPLEX Health Check

.DESCRIPTION
The script generates health check report for EMC VPLEX virtual arrays

Parameters:

-ip <ip1,ip2,..>     VPLEX Management IP or host names 
-all                 all VPLEX arrays listed in cred file
-credfile            file that contains credentials in json format
                        {
                            "vplex01":  {
                                              "Username":  "username1",
                                              "Password":  "password1",
                                          },
                            "vplex02":  {
                                              "Username":  "username2",
                                              "Password":  "password2"
                                          }
                        }
                                
                        the script will prompt for credentials if no credfile is provided, or VplexIP is missing         

.EXAMPLE

health_check_vplex.ps1 -ip vplex01 -credfile vplexCreds.json

.NOTES


.LINK

#>


[CmdletBinding()] 
param ( 
    [parameter( Position=0,
                ValueFromPipeline=$true)]
                #ValueFromPipelineByPropertyName=$true)]
    [string[]]$ip,
    [switch]$help,
    [switch]$entireinventory,
    [switch]$healthcheck,
    [switch]$frontports,
    [string]$credfile
) 

BEGIN {
    # [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

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

PROCESS {




    function execVplexCmd {

        param(
            [string]  $IP,
            [string]  $HTTPMethod,
            [string]  $Username,
            [string]  $Password,
            [string]  $Cmd

        )

        $BackgroundCmdCheckIntSec=10
        $MaxBackgroundCmdCheckAttempts=30

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


        } catch [System.Net.WebException] {
    
            $errMsg=$_.Exception.toString()
            Write-Error $errMSg

            exit 1
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
                        exit 1
                    } 
                }

                if( $webReply.StatusCode -eq 200 ) {
                    break
                }
            }
            Write-Progress -Activity "Executing `"$vplexCmd $vplexCmdArgs`" on $IP" -Completed -Status "Completed."
        }




        if( $webReply.StatusCode -eq 200 ) {
        
            $webReplyContent=convertfrom-json $webReply.content

            if( $webReplyContent.response.context -ne $null ) {
                $webReplyContent.response.context
            }

            if( $webReplyContent.response.'custom-data' -ne $null ) {
                $webReplyContent.response.'custom-data' -replace "\033\[\d+m",""
            }
        } else {
        
            write-error "No response from VPLEX"

        }
    }

    function readCredFile( $credfilename ) {
        
        try{
            cat -raw $credfilename | ConvertFrom-Json

        }
        catch {
            write-error "Error reading credential file $credfilename"
        }
    }

    function frontPortReport( $ip, $creds ) {
        "== VPLEX Front Port Volume Count ======================================="
        ""

        foreach( $vplexIP in $ip ) {

            $vplexCmd="/engines/**/directors/*"
            $directors=execVplexCmd -IP $vplexIP -Username $creds.$vplexIP.username -Password $creds.$vplexIP.password -HTTPMethod "GET" -Cmd $vplexCmd

            $vplexCmd="/clusters/cluster-1/exports/ports/*"
            $ports=execVplexCmd -IP $vplexIP -Username $creds.$vplexIP.username -Password $creds.$vplexIP.password -HTTPMethod "GET" -Cmd $vplexCmd

            $vplexPortInfo=@()

            foreach( $port in $ports ) {

                $dirID,$dirAB,$FC=$port.name -split "-"
                $dirID=$dirID -replace "P",""
                
                $dirName=($directors | where { $_.'director-id' -like "*$dirID" }).name

                $portName=$dirName+"-" + $FC

                $portName

                $portProperties=[ordered]@{ Port=$portName }
                        #InitiatorCount=$port.'discovered-initiators'.count
                        #VolumeCount=$port.exports.count
                #}

                $portProperties

                $vplexPortInfo+=New-Object -TypeName PSObject -Property $portProperties

            }

            "-- VPLEX $vplexIP -------------------------------------------------"
            $vplexPortInfo
        }
    }

    function runHealthCheck( $ip, $creds ) {

        "== VPLEX Health Check Report ==========================================="
        ""

        foreach( $vplexIP in $ip ) {

            $vplexCmd="health-check -f"
            "`n-- Executing `"$vplexCmd`" on VPLEX $vplexIP ----------------------------`n"

            #write-debug $vplexIP + " " + $vplexCredentials.$vplexIP.username + " " + $vplexCredentials.$vplexIP.password
            execVplexCmd -IP $vplexIP -Username $creds.$vplexIP.username -Password $creds.$vplexIP.password -HTTPMethod "POST" -Cmd $vplexCmd
            ""

            $vplexCmd="health-check --front-end --verbose"
        
            "`n-- Executing `"$vplexCmd`" on VPLEX $vplexIP ----------------------------`n"
            execVplexCmd -IP $vplexIP -Username $creds.$vplexIP.username -Password $creds.$vplexIP.password -HTTPMethod "POST" -Cmd $vplexCmd
            ""

            $vplexCmd="health-check --back-end --verbose"
            "`n-- Executing `"$vplexCmd`" on VPLEX $vplexIP ----------------------------`n"
            execVplexCmd -IP $vplexIP -Username $creds.$vplexIP.username -Password $creds.$vplexIP.password -HTTPMethod "POST" -Cmd $vplexCmd
            ""

        }

    }

    if( $help -or -not $ip ) {
        "Usage: health_check_vplex.ps1 [-ip <ip1,ip2,...>]|[-entireinventory] [-healtcheck] [-frontports] [-credfile <credfile>]"
        exit
    }

    if( $credfile ) {
        $vplexCredentials=readCredFile $credfile
    }

    if( $entireinventory ) {
        
        $ip=($vplexCredentials | Get-Member -MemberType NoteProperty).Name

    } else {

        foreach( $vplexip in $ip ) {

            $vplexCredentials
    
            if( -not ($vplexCredentials.$vplexIP.username -and $vplexCredentials.$vplexIP.password ) ) {
            
                    $cred=Get-Credential -username $Username -Message "Credentials for VPLEX $IP"
                    $Username=$cred.UserName
            
                    $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cred.password)
                    $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

                    $newcred=New-Object System.Object
                    $newcred |  Add-Member -Type NoteProperty -name "Username" -Value $Username
                    $newcred |  Add-Member -Type NoteProperty -name "Password" -Value $Password
                
                    $newvplex=New-Object System.Object
                    $newvplex | Add-Member -Type NoteProperty -name $vplexip -Value $newcred
            }
        }
    }

    "Computer: " + (hostname)
    "Script: " + $MyInvocation.MyCommand.Definition
    ""
    (get-date).toString()
    ""

    if( $frontports ) {
        
        frontPortReport $ip $vplexCredentials
    }
    
    if( $healthcheck ) {

        
        runHealthCheck $ip $vplexCredentials
    }


}






