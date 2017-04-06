# CAVA CLASS

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
#	[ValidateSet("SaturationPercent","ScansPerSec")]$Metric 

)

$DefaultSampleInterval=10
$DefaultCount=10000
#$DefaultMetric="SaturationPercent"

if( ! $SampleInterval ) { $SampleInterval=$DefaultSampleInterval }
if( ! $Count ) { $Count=$DefaultCount }
#if( ! $Metric ) { $Metric=$DefaultMetric }

"CAVA Utilization Report"
"-----------------------"
"SampleInterval:	$SampleInterval"
"Count:		$count"
#"Metric:		$Metric"
"CAVA Servers: 	$ComputerName"
""

$HeadRow="{0,-10} {1,-8} " -f "",""
$SecondRow="{0,10} {1,8} " -f "Date","Time" 

foreach( $Server in $ComputerName ) {
	$HeadRow+="{0,15} " -f $Server
	$SecondRow+=" Scans  Ms Busy " 

}

#$HeadRow+="{0,7}" -f "Average"

$HeadRow
$SecondRow


function AVUtilReport {
	for( $i=0; $i -lt $Count; $i++ ) {

		$OutputLine=$(get-date -uformat "%m-%d-%Y %H:%M:%S") + " "
#		$Average=0
#		$ServerCount=$ComputerName.count

		foreach( $CAVAServer in $ComputerName ) {
			$cava=gwmi -ComputerName $CAVAServer -namespace root\emc -class CAVA 

			if( $cava.State -match "NORMAL" ) {
				$SaturationPercent=$cava.SaturationPercent*100
				$OutputLine += "   {0,3:N0} {1,3:N0} {2,3:N0}% " -f $cava.ScansPerSec,$cava.MilliSecsPerScan,$SaturationPercent
#				$Average+=$cava.$Metric
			} else {
				$OutputLine += "{0,15} " -f $cava.State
#				$ServerCount--
			}
		}
#		$Average=$Average/$ServerCount
#		$OutputLine += "{0,7:N1}" -f $Average
		$OutputLine 

		sleep $SampleInterval
	}
}

AVUtilReport

