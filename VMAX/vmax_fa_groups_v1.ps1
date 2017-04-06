<#

.SYNOPSIS
The script produces a report that shows how FAs are groupped into masking views on a EMC VMAX2 array. 

.DESCRIPTION
The script uses EMC Solution Enabler (SE) command symaccess to get source data. The command 
must be accessbile through the "PATH" environent variable.


Parameters:

-SID <Symmetrix ID>          self explanatory
-detail                      show detailed masking view list

.EXAMPLE

vmax_fa_groups.ps1 -sid 1234 [-detail]

.NOTES


.LINK

#>


param(
    [string]$SID,
	[switch]$detail
)

if( -not $SID  ) {
    "Usage: vmax_fa_groups.ps1 -SID <symm ID> [-detail]"
    exit
}

(get-date).ToString()
""

$env:SYMCLI_OUTPUT_MODE='XML'
#[xml]$vmaxViews=cat 2638_views.xml
[xml]$vmaxViews=symaccess -sid $SID list view -detail
$env:SYMCLI_OUTPUT_MODE="STANDARD"

if( $vmaxViews -eq $null ) {
	"Unknown Symmetrix ID $SID" 
    exit
}

$portGroups=@{}



$SID=$vmaxViews.SymCLI_ML.Symmetrix.Symm_Info.Symid
"-- VMAX $SID -------------------------------------------------"
""

$viewNames=@()

foreach( $view in $vmaxViews.SelectNodes('//View_Info') ) { 

            $viewName=$view.view_name
			
			if( $viewNames.contains( $viewName ) ) {
				continue
			} else {
				$viewNames+=$viewName
			}
			
			$initGrpName=$view.init_grpname
			
			
#			$view.port_info.Director_Identification | sort dir | 
			$portGroup=""
			
			foreach( $dir_ident in ($view.port_info.Director_Identification | 
					sort @{ e={ $_.dir -replace "\D" -as [int]}},@{ e={ $_.dir -replace "FA-\d*" }},@{ e={ $_.port} } )) {
				$portGroup+=($dir_ident.dir -replace "FA-" ) + ":" + $dir_ident.port +  "_"
			}
			
			$portGroup=$portGroup.trim("_")
			
			if( -not $portGroups[$portGroup] ) {
				$portGroups[$portGroup]=@{viewCount=0;totalGB=0;viewtotalGB=@{} }
				
			}
			
			$portGroups[$portGroup].viewCount++
			$portGroups[$portGroup].totalGB+=($view.Totals.total_dev_cap_mb/1KB)
			$portGroups[$portGroup].viewTotalGB[$viewName]=($view.Totals.total_dev_cap_mb/1KB)

			
}

"{0,-45} {1,-5} {2,-10}" -f "FA Group","Views","Total GB"
"{0,-45} {1,-5} {2,-10}" -f "---------------------------","-----","----------"


foreach( $portGroup in $portGroups.keys | 
		sort @{ e={ $_ -replace "\w{1}:.*" -as [int]}},
			 @{ e={ ($_ -replace "_.*") -replace "\d*" }},
			 @{ e={ ($_ -replace "_.*") -replace "^.*:" }}
		) {
	#$portGroup + " " + $portGroups[$portGroup]
	"{0,-45} {1,5:N0} {2,10:N0}" -f $portGroup,$portGroups[$portGroup].viewCount,$portGroups[$portGroup].totalGB
	
}

if( $detail ) {
	""
	""
	"{0,-45} {1,-40} {2,10:N0}" -f "FA Group","Masking View","Total GB"
	"{0,-45} {1,-40} {2,10:N0}" -f "-----------------------","-----------------","--------"
	
	foreach( $portGroup in $portGroups.keys | 
			sort @{ e={ $_ -replace "\w{1}:.*" -as [int]}},
			 @{ e={ ($_ -replace "_.*") -replace "\d*" }},
			 @{ e={ ($_ -replace "_.*") -replace "^.*:" }}				
			) {
		foreach( $viewName in $portGroups[$portGroup].viewTotalGB.keys | sort ) { 
			"{0,-45} {1,-40} {2,10:N0}" -f $portGroup, $viewName, $portGroups[$portGroup].viewTotalGB[$viewName]
		}
		"-----------------------------------------------------"
	}
}

