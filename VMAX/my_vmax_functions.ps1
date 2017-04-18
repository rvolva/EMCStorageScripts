# == VMAX Functions =========================================

# Version: 1.0


function set-climode-xml {
    $env:SYMCLI_OUTPUT_MODE='XML'
}

function set-climode-text {
    $env:SYMCLI_OUTPUT_MODE=''
}

function get-symDevSortedBySize {

	param (
		[string]$sid
	)
	
	if( $sid -eq "" ) {
		"Usage: get-symDevSortedBySize -sid <SID>"
		exit
	}
	
	symdev -sid $sid -nomember list | sls TDEV | foreach { 
			$line=$_ -split "\s+"
			[PSCustomObject]@{ Dev=$line[0];SizeMB=$line[$line.count-1]} 
		}  | sort { $_.SizeMB -as [long] }
}


<#-- Points Solutions Enabler to a remove SE server using an alias defined in a json file referenced by $se_hosts_file:
 {
        "<alias>": "<server name>"
}
#>

function set-se ([string]$site) {

    if( -not (Test-Path $se_hosts_file ) ) {
        Write-Error "$se_hosts_file file missing"
    }

    $se_hosts=cat -raw $se_hosts_file | ConvertFrom-Json

    $env:SYMCLI_CONNECT=$se_hosts.$site
    "SYMCLI HOST: " + $env:SYMCLI_CONNECT
}

function get-se {
    $env:SYMCLI_CONNECT
}
