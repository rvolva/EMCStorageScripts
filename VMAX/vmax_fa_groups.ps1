<#

.SYNOPSIS
Show VMAX front port groupings

.DESCRIPTION

There are two types of report: summary and detailed. 

The summary report shows port groupings and total number of masking views and storage mapped to the ports.

The detailed report shows summary and detailed list of masking views for each port grouping.

The script uses EMC Solution Enabler (SE) command "symaccess" to source data. Location of the command must be added t "PATH" environent variable.


.PARAMETER SID

Symmetrix ID

.PARAMETER Detail

show detailed masking view list

.PARAMETER MaskingView

Limit output to a specific masking view only

.EXAMPLE

PS> vmax_fa_groups.ps1 -sid 1234,4563

.EXAMPLE

PS> vmax_fa_groups.ps1 -sid 1234,4563 -Detail

.EXAMPLE

PS> vmax_fa_groups.ps1 -sid 1234 -Detail -MaskingView mv1


.NOTES


.LINK

#>


[CmdletBinding(DefaultParameterSetName="Help")]
param(
    [Parameter(Mandatory=$true,Position=0,ParameterSetName="SummaryReport")]
    [Parameter(Mandatory=$true,Position=0,ParameterSetName="DetailedReport")]
    [string[]]$SID,

    [Parameter(Mandatory=$true,Position=0,ParameterSetName="DetailedReport")]
    [Alias("d")]
	[switch]$Detail,

    [Parameter(Position=0,ParameterSetName="DetailedReport")]
    [Alias("mv")]
	[string]$MaskingView,

    [Parameter(ParameterSetName="Help")]
    [Alias("h")]
    [switch]$Help
)

$SCRIPT_VERSION="2.0"

if ( $PsCmdlet.ParameterSetName -eq "Help" )
{
    get-help $script:MyInvocation.MyCommand.Definition
    exit 1
}

"Computer: " + (hostname)
"Script: " + $MyInvocation.MyCommand.Definition
"Version: " + $SCRIPT_VERSION
""

(get-date).ToString()
""

$env:SYMCLI_OUTPUT_MODE='XML'

foreach( $symID in $SID ) {

    #[xml]$vmaxViews=cat symaccess-list-view-detail.xml

    $symAccessCmd="symaccess -sid $symID list view -detail"

    if( $MaskingView ) {
        $symAccessCmd+=" -name {0}" -f $MaskingView
    }

    [xml]$vmaxViews=iex $symAccessCmd

    if( $vmaxViews -eq $null ) {
	    "Unknown Symmetrix ID {0}" -f $symID
        continue
    }

    $portGroups=@{}

    $symID=$vmaxViews.SymCLI_ML.Symmetrix.Symm_Info.Symid
    "== VMAX {0} =======================================================================" -f $symID
                                                      
    ""

    $viewNames=@()

    foreach( $view in $vmaxViews.SelectNodes('//View_Info') ) { 

                #if( $MaskingView -and $view.view_name -ne $MaskingView ) {
                #    continue
                #}

                $viewName=$view.view_name
			
			    if( $view.Totals.total_dev_cap_mb -eq $null -or $viewNames.contains( $viewName ) ) {
				    continue
			    } else {
				    $viewNames+=$viewName
			    }
			
			    $initGrpName=$view.init_grpname
			
			
			    $portGroup=""
			
			    foreach( $dir_ident in ($view.port_info.Director_Identification | 
					    sort @{ e={ $_.dir -replace "\D" -as [int]}},@{ e={ $_.dir -replace "FA-\d*" }},@{ e={ $_.port} } )) {

				    #$portGroup+="{0,-5} " -f (($dir_ident.dir -replace "FA-" ) + ":" + $dir_ident.port +  " ")
                    $portGroup+="{0} " -f (($dir_ident.dir -replace "FA-" ) + ":" + $dir_ident.port)
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
    "{0,-45} {1,-5} {2,-10}" -f ( "-" * 45 ) ,( "-" * 5 ), ( "-" * 10 )


    foreach( $portGroup in $portGroups.keys | 
		    sort @{ e={ $_ -replace "\w{1}:.*" -as [int]}},
			     @{ e={ ($_ -replace "_.*") -replace "\d*" }},
			     @{ e={ ($_ -replace "_.*") -replace "^.*:" }}
		    ) {
	    #$portGroup + " " + $portGroups[$portGroup]
	    "{0,-45} {1,5:N0} {2,10:N0}" -f $portGroup,$portGroups[$portGroup].viewCount,$portGroups[$portGroup].totalGB
	
         $arrayTotalGB+=$portGroups[$portGroup].totalGB
    }

    "{0,-45} {1,-5} {2,-10}" -f ( "-" * 45 ) ,( "-" * 5 ), ( "-" * 10 )
    "{0,-45} {1,5:N0} {2,10:N0}" -f "TOTAL:",$viewNames.count,$arrayTotalGB

    if( $detail ) {
	    ""
	    ""
	    "{0,-45} {1,-40} {2,10:N0}" -f "FA Group","Masking View","Total GB"
	    "{0,-45} {1,-40} {2,10:N0}" -f ( "-" * 45 ) , ( "-" * 40 ) ,( "-" * 10 )
	
	    foreach( $portGroup in $portGroups.keys | 
			    sort @{ e={ $_ -replace "\w{1}:.*" -as [int]}},
			     @{ e={ ($_ -replace "_.*") -replace "\d*" }},
			     @{ e={ ($_ -replace "_.*") -replace "^.*:" }}				
			    ) {
		    foreach( $viewName in $portGroups[$portGroup].viewTotalGB.keys | sort ) { 
			    "{0,-45} {1,-40} {2,10:N0}" -f $portGroup, $viewName, $portGroups[$portGroup].viewTotalGB[$viewName]
		    }
		    "-" * 97
	    }
    }
    ""
}


$env:SYMCLI_OUTPUT_MODE=""
