# CAVA CLASS

# May need to register CAVA WMI class for this script to work:
#
# On each CAVA server:
#
# Open command window as Administrator and execute the following commands:
# cd %SystemRoot%\system32\wbem\mof 
# notepad cava.mof
#		Add as the first line in the file (incuding the # sign before PRAGMA)
#		#PRAGMA AUTORECOVER
# 		save cava.mof
# mofcomp cava.mof 

# AVEngineState     : Up
# AVEngineType      : Network Associates
# FilesScanned      : 2204761
# Health            : Good
# MilliSecsPerScan  : 13.7777777777778
# Name              : CAVAInstance01
# SaturationPercent : 0.0124
# ScansPerSec       : 0.9
# State             : NORMAL
# Version           : 6.5.0.0

param ( 
	[Parameter(Mandatory=$True)][string[]]$ComputerName,
	[int]$SampleInterval, 
	[int]$Count

)

$DefaultSampleInterval=10
$DefaultCount=10000
#$DefaultMetric="SaturationPercent"

if( ! $SampleInterval ) { $SampleInterval=$DefaultSampleInterval }
if( ! $Count ) { $Count=$DefaultCount }

"CAVA Utilization Report"
"-----------------------"
"SampleInterval (sec):	$SampleInterval"
"Count:			$count"
"CAVA Servers: 		$ComputerName"
""

$HeadRow="{0,-10} {1,-8} " -f "Date","Time" 
$SecondRow="{0,10} {1,8} " -f "----------","--------" 

foreach( $Server in $ComputerName ) {
	$HeadRow+="| {0,14} |  " -f $Server
	$SecondRow+="Scans    Ms   Busy  " 

}

$HeadRow
$SecondRow


function AVUtilReport {
	for( $i=0; $i -lt $Count; $i++ ) {

		$OutputLine=$(get-date -uformat "%m-%d-%Y %H:%M:%S") + " "

		foreach( $CAVAServer in $ComputerName ) {
			$cava=gwmi -ComputerName $CAVAServer -namespace root\emc -class CAVA 

			if( $cava.State -match "NORMAL" ) {
				$SaturationPercent=$cava.SaturationPercent*100
				$OutputLine += "{0,5:N1} {1,5:N0} {2,5:N1}%  " -f $cava.ScansPerSec,$cava.MilliSecsPerScan,$SaturationPercent
			} else {
				$OutputLine += "{0,18}  " -f $cava.State
			}
		}
		$OutputLine 

		sleep $SampleInterval
	}
}

AVUtilReport

