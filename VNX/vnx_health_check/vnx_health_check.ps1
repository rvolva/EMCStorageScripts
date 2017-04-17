<#

.SYNOPSIS
Health Check script for VNX1 and VNX2

.DESCRIPTION
The script uses NaviSecCLI commands to get VNX health check data:
- hardware failures
- pool utilization


Parameters:

-h <VNX SP IP>[,<IP>]  		VNX SP IP or hostname
-splist <file>             	a text file containing list of VNX SP IPs or host names one per line, 
                            lines starting with # are excluded
-user <user name>			VNX user name
-password <password>		VNX password
							   
-pool                       show thin pool usage
-hwfail                     show h/w failures 
-cache                      show SP cache enabled/disabled status
-sp							show SP Port Status
-hba						show Initiator login status
-all						show all

.EXAMPLE

health_check_VNX.ps1 -vnxlist vnx_list.txt -pool -hwfail

.NOTES


.LINK

#>

param(
    [string]$h,
    [string]$splist,
	[string]$user,
	[string]$password,
    [switch]$hwfail,
    [switch]$pool,
    [switch]$cache,
	[switch]$sp,
	[switch]$hba,
	[switch]$all
)

$VNXSPLIST=@()
$ConnectionErrorSP=@()
$VNXINFO=[ordered]@{}

$credentials=if( $user -ne "" -and $password -ne "" ) { "-user $user -password $password -scope 0" }
$NAVISECCLICMD="naviseccli $credentials"

if( $h -ne "" ) {
	$VNXSPLIST=$h.split()
}

if( $splist -ne "" ) {
    if( test-path $splist ) {
        foreach( $h in ( gc $splist | select-string -Pattern "^#|^$" -NotMatch )) {
			if( -not $VNXSPLIST.contains($h) ) {
				$VNXSPLIST+=$h
			}
			#if( -not $VNXINFO.contains($h) ) {
			#	$VNXINFO.$h=New-PSObject -TypeName PSObject
			#}
        }
    }
}   

if( $VNXSPLIST.length -eq 0 ) {
    "Usage: health_check_VNX.ps1 -h <SP IP> | -splist <SP IP list file> [-user <user>] [-password <password>] [-hwfail] [-pool] [-cache]"
    exit
}


(get-date).ToString()
""

function getArrayBaseInfo {
   
   foreach( $h in $VNXSPLIST ) {

		$arrayInfo=[ordered]@{}
		try {
			[xml]$xmlOut=iex "$NAVISECCLICMD -h $h -Xml arrayname"
			$arrayInfo.arrayName		=($xmlOut.selectnodes('//VALUE/PARAMVALUE[@NAME="Array Name"]/VALUE')).InnerText
		} catch {
			"Coudn't connect to specified host " + $h
			$Script:ConnectionErrorSP+=$h
			continue
		}
		
		[xml]$xmlOut=iex "$NAVISECCLICMD -h $h -Xml getagent"
		$arrayInfo.arraySerial	=($xmlOut.selectnodes('//VALUE/PARAMVALUE[@NAME="Serial No"]/VALUE')).InnerText
		$arrayInfo.arrayModel	=($xmlOut.selectnodes('//VALUE/PARAMVALUE[@NAME="Model"]/VALUE')).InnerText
		$arrayInfo.codeRevision	=($xmlOut.selectnodes('//VALUE/PARAMVALUE[@NAME="Revision"]/VALUE')).InnerText
		$arrayInfo.SPMemory		=($xmlOut.selectnodes('//VALUE/PARAMVALUE[@NAME="SP Memory"]/VALUE')).InnerText
		$arrayInfo.arrayFamily=if( $arrayInfo.arrayModel.substring(4,1) % 2 -eq 0 ) {  "VNX2" } else { "VNX1" }
			

		$VNXINFO.add($h,(New-Object -TypeName PSObject -Property $arrayInfo))
	}
	
} # End of getArrayBaseInfo

function removeArraysWithConnectionErrors {

	foreach( $h in $ConnectionErrorSP ) {
		$VNXINFO.remove($h)
	}
}

function printArrayHeader ( $arrayName, $arraySerial ) {
        ""
		"-- VNX $arrayName ( " + $arraySerial + " ) ---------------------------------------"
        ""
}


getArrayBaseInfo
removeArraysWithConnectionErrors

"== VNX Health Check Inventory =============================================================="
$VNXINFO.values | ft 	@{ n="Array Name"; e={ $_.arrayName } },
						@{ n="Serial #"; e={ $_.arraySerial } },
						@{ n="Model"; e={ $_.arrayModel } },
						@{ n="Code Revision"; e={ $_.codeRevision } },
						@{Name="SP Memory (MB)";e={ "{0:N0}" -f [int]$_.SPMemory };a="Right" }


function hwFailureReport {
						
    "== VNX H/W Failures ====================================================="
    ""

    foreach( $h in $VNXINFO.keys ) {
        
        printArrayHeader $VNXINFO.$h.arrayName $VNXINFO.$h.arraySerial
    
        iex "$NAVISECCLICMD -h $h faults -list"
		""
    }
}

function storagePoolReport {

    "== VNX Storage Pools ====================================================="

    foreach( $h in $VNXINFO.keys ) {
	
        printArrayHeader $VNXINFO.$h.arrayName $VNXINFO.$h.arraySerial 

		[xml]$xmlOut=iex "$NAVISECCLICMD -h $h -Xml storagepool -list"
		$poolInfo=""
		
		$poolsInfo=@()
		
		$xmlOut.selectNodes('//PARAMVALUE[@NAME]') | foreach {
			$xmlNode=$_
			
			switch ( $xmlNode.NAME ) {
				"Pool Name" 					{ $poolInfo=[ordered]@{};$poolInfo."Pool Name"=$xmlNode.VALUE }
				"Raid Type"						{ $poolInfo."Raid Type"			=$xmlNode.VALUE }
#				"Description"					{ $poolInfo.Description			=$xmlNode.VALUE}
				"Disk Type"						{ $poolInfo."Disk Type"			=$xmlNode.VALUE }
				"State"							{ $poolInfo.State				=$xmlNode.VALUE }
				"Status"						{ $poolInfo.Status				=$xmlNode.VALUE }
				"User Capacity (GBs)"			{ $poolInfo.UserCapGB			=$xmlNode.VALUE }
				"Available Capacity (GBs)"		{ $poolInfo.AvailableCapGB		=$xmlNode.VALUE }
				"Percent Full"					{ $poolInfo.PctFull				=$xmlNode.VALUE }
				"Total Subscribed Capacity (GBs)"	{ $poolInfo.SubscribedCapGB	=$xmlNode.VALUE }
				"Percent Subscribed"			{ $poolInfo.PctSubscribed		=$xmlNode.VALUE }
				"LUNs"							{ $poolsInfo+=New-Object -TypeName PSObject -Property $poolInfo } 
			}
		}
		
		$poolsInfo | ft -wrap "Pool Name",
						"Raid Type",
						"Disk Type",
						State,
						Status,
						@{n="Cap (GB)";e={ "{0:N0}" -f [int]$_.UserCapGB };a="right"},
						@{n="Avail Cap (GB)";e={ "{0:N0}" -f [int]$_.AvailableCapGB };a="right"},
						@{n="Util (%)";e={ "{0:N0}" -f [int]$_.PctFull };a="right"},
						@{n="Subscr Cap (GB)";e={ "{0:N0}" -f [int]$_.SubscribedCapGB };a="right"},
						@{n="Subscr (%)";e={ "{0:N0}" -f [int]$_.PctSubscribed };a="right"}
    }
}

function cacheStateReport {
    "== VNX H/W SP Cache Status ======================================================================"

	$arraysCacheState=[ordered]@{}
	
    foreach( $h in $VNXINFO.keys ) {
		
		$cacheState=[ordered]@{}
		
		if( $VNXINFO.$h.arrayFamily -eq "VNX1") {
			[xml]$xmlOut=iex "$NAVISECCLICMD -h $h -Xml getcache -state"
		} else {
			[xml]$xmlOut=iex "$NAVISECCLICMD -h $h -Xml cache -sp -info -state"
		}

		$cacheState."Array Name"		=$VNXINFO.$h.arrayName
		
		$xmlOut.selectnodes('//VALUE/PARAMVALUE[@NAME]') | foreach {
			$valueName				=$_.NAME.trim()
			$cacheState.$valueName	=$_.VALUE
		}
		
		$arraysCacheState.add($h,(New-Object -TypeName PSObject -Property $cacheState))
    }
	$arraysCacheState.values | ft 
}


function spPortStatusReport {

	"== SP Port Status ====================================================="

	
	$arraysSPPortStatus=[ordered]@{}
   
    foreach( $h in $VNXINFO.keys ) {

		printArrayHeader $VNXINFO.$h.arrayName $VNXINFO.$h.arraySerial 
		
		[xml]$xmlOut=iex "$NAVISECCLICMD -h $h -Xml port -list -sp"
		
		$spPortStatus=[ordered]@{}
		
		$xmlOut.selectNodes('//PARAMVALUE[@NAME]') | foreach {
			$xmlNode=$_
			
			switch ( $xmlNode.NAME ) {
				"SP Name" 					{ $spName=$xmlNode.VALUE }
				"SP Port ID" 				{ $spPortID=$xmlNode.VALUE }
				"Link Status" 				{ $spLinkStatus=$xmlNode.VALUE }
				"Port Status" 				{ $spPortStatus.add( "$spName`:$spPortID", "$spLinkStatus / $($xmlNode.VALUE)" ) }
			}
		}
		
		$spPortStatus
	}
}


function hbaStatusReport {

	"== HBA Port Status ====================================================="

	
	$arraysHbaStatus=[ordered]@{}
   
    foreach( $h in $VNXINFO.keys ) {

		printArrayHeader $VNXINFO.$h.arrayName $VNXINFO.$h.arraySerial 
		
		[xml]$xmlOut=iex "$NAVISECCLICMD -h $h -Xml port -list -hba"
		
		$xmlOut.selectNodes('//PARAMVALUE[@NAME]') | foreach {
			$xmlNode=$_
			
			switch ( $xmlNode.NAME.trim() ) {
				"Server Name" 				{ 	if( $serverName -ne $xmlNode.VALUE ) {
														$serverName=$xmlNode.VALUE;
														""
														$serverName
														""
														"SP   Port  LoggedIn  HBA UID" 
														"---- ----  --------  ---------------------------------------"
												} 
											}
				"HBA UID"					{ $hbaUID=$xmlNode.VALUE } 
				"SP Name"					{ $spName=$xmlNode.VALUE; $loginStatus=@{} }
				"SP Port ID" 				{ $spPortID=$xmlNode.VALUE }
				"Logged In" 				{ 	"{0,4} {1,4} {2,10} {3}" -f $spName,$spPortID,$xmlNode.VALUE,$hbaUID; }
			}
		}
		
    }
	

} # End of hbaStatusReport

if( $hwfail -or $all ) {
	hwFailureReport
}

if( $pool -or $all ) {
	storagePoolReport
}

if( $cache -or $all ) {
	cacheStateReport
}

if( $sp -or $all ) {
	spPortStatusReport
}

if( $hba -or $all ) {
	hbaStatusReport
}