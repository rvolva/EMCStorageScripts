<#

.SYNOPSIS
VMAX TDEV Report

.DESCRIPTION
The script generates a report that shows on one screen device ID, size, allocated capacity, and storage group

Parameters:

-SID <symid>            self explanatory
-insg                   include only devices that are in a Storage Group
-notinsg                include only devices that are not in a Storage Group
-notinview              include only devices that are in SG but not in a view
-detail                 show device list, without this option the report will show totals only
-mindevsize <n GB>      exclude devices small than n GB
-maxallocationpct <n>   include devices with allocation percentage equal or less the specifed number 
-sgolderthandays <n>    include devices in Storage groups that were modified more than <n> days ago

.EXAMPLE

vmax_tdev_allocation_report.ps1 -sid 5243 -notinsg
vmax_tdev_allocation_report.ps1 -sid 5243,2343 -notinsg -detail


.NOTES


.LINK

#>

[CmdletBinding()] 
param ( 
    [parameter( Position=0,
                ValueFromPipeline=$true)]
                #ValueFromPipelineByPropertyName=$true)]
    [string[]]$SID,
    [switch]$insg,
    [switch]$notinsg,
    [switch]$notinview,
    [switch]$detail,
    [int]$mindevsize,
    [int]$maxallocationpct,
    [int]$sgolderthandays,
    [switch]$help
   
) 



PROCESS
{
    function generateTDEVReport {

        param(
            [string]$vmaxSID,
            [bool]$insg,
            [bool]$notinsg,
            [bool]$notinview,
            [bool]$detail,
            [int]$mindevsize,
            [int]$maxallocationpct,
            [int]$sgolderthandays
        )

        $env:SYMCLI_OUTPUT_MODE='XML'

        try {
            Write-Host "Collecting TDEV allocation data using: symcfg -sid $vmaxSID list -tdev"
            [xml]$xmlSymCfg=symcfg -sid $vmaxSID list -tdev
#           [xml]$xmlSymCfg=cat symcfg-list-tdev.2638.xml

            Write-Host "Collecting TDEV Storage Group assigment data using: symaccess -sid $vmaxSID -type stor list -dev '0:FFFFF'"
            [xml]$xmlSymAccess=symaccess -sid $vmaxSID -type stor list -dev '0:FFFFF'
#           [xml]$xmlSymAccess=cat symaccess-type-stor-list.2638.xml

            Write-Host "Collecting RDF device list using: symrdf -sid $vmaxSID list"
            [xml]$xmlSymRDF=symrdf -sid $vmaxSID list 
#           [xml]$xmlSymRDF=cat symrdf-list.2638.xml

            Write-Host "Collecting Clone device list using: symclone -sid $vmaxSID list"
            [xml]$xmlSymClone=symclone -sid $vmaxSID list 
#           [xml]$xmlSymClone=cat symclone-list.2638.xml


        }

        catch [System.Management.Automation.CommandNotFoundException] {
            write-error "Failed to execute EMC Solutions Enabler commands. Make sure Solutions Enabler is installed on the host and bin directory is added to the PATH environment variable."
            exit
        }

        
        if( $xmlSymCfg -eq $null ) {
			"Unknown SymID: $vmaxSID"
            ""
			continue
		}

        $fullVMAXSID=$xmlSymCfg.SymCLI_ML.Symmetrix.Symm_Info.Symid

        ""
        "--- VMAX $fullVMAXSID -------------------------------------------------"
        ""

        $totalTDEVcount=$xmlSymCfg.selectnodes("//Device[tdev_status='Bound']").count
        $processedTDEVcount=0
        $pctComplete=0

        $olderThanDate=(get-date).adddays(-$sgolderthandays)
         
        $devsInfo=@()

        [long]$total_Size_GB=0
        [long]$total_Used_GB=0

        foreach( $xmlDev in $xmlSymCfg.SelectNodes("//ThinDevs/Device[tdev_status='Bound']") ) {

            $currentPctComplete=[math]::Round(100*$processedTDEVcount/$totalTDEVcount)

            if( $currentPctComplete -gt $lastPctComplete ) {
                $lastPctComplete=$currentPctComplete
            
                Write-Progress -Activity "Analyzing $totalTDEVcount TDEV devices on VMAX $fullVMAXSID ..." -PercentComplete $lastPctComplete -Status "Please wait."
            }
            
            $processedTDEVcount++

            $devInfo=[ordered]@{}
            $dev_name=$xmlDev.dev_name
            $devInfo.add( "DevName", $xmlDev.dev_name)
            $devInfo.add( "Size_GB", [int]$xmlDev.total_tracks_gb)
            $devInfo.add( "Used_GB", [int]$xmlDev.alloc_tracks_gb)
            $devInfo.add( "Used_Pct", [int]$xmlDev.pool_alloc_percent)


            $sgName="-"
            $sgUpdateDate="-"
            $sgViewCount=0

            foreach( $xmlSG in $xmlSymAccess.selectnodes("//Device[dev_name='$dev_name']").Storage_Group.Group_Info ) {
                    
                if( $xmlSG.group_last_update_time -ne "N/A" ) {

                    if( $xmlSG.Status -eq "IsParent" ) {
                        continue
                    }

                    $sgName=$xmlSG.group_name
                    $sgUpdateDate=($xmlSG.group_last_update_time -split "\S+ \S+ \S+ \S+ (.*)")[1]
                    $sgViewCount=$xmlSG.view_count

                }
            }

            $devInfo.add("SG_Name",$sgName)
            $devInfo.add("SG_Update_Date",$sgUpdateDate)
            #$devInfo.add("SG_View_Count",$sgViewCount)

            if( $xmlSymRDF.SelectNodes("//Dev_Info[dev_name='$dev_name']") -ne $null ) { 
                $devInfo.add("RDF","R")
            } else {
                $devInfo.add("RDF","-")
            }

            if( $xmlSymClone.SelectNodes("//Source[dev_name='$dev_name']") -ne $null -or $xmlSymClone.SelectNodes("//Target[dev_name='$dev_name']") -ne $null ) {
                $devInfo.add("Clone","C")
            } else {
                $devInfo.add("Clone","-")
            }


            $inScope=$True

            if( $inScope -and $insg -and $sgName -eq '-' ) {
                $inScope=$False
            }

            if( $inScope -and $notinsg -and $sgName -ne '-' ) {
                $inScope=$False
            }

            if( $inScope -and $mindevsize -ne 0 -and $devInfo.Size_GB -lt [int]$mindevsize ) {
                $inScope=$False
            }

            if( $inScope -and $maxallocationpct -ne 0 -and $devInfo.Used_Pct -gt $maxallocationpct ) {
                #"Exclude: " + $devInfo.DevName + " " + $devInfo.Used_Pct
                $inScope=$False
            }

            if( $inScope -and $sgolderthandays -ne 0 -and [datetime]$devInfo.SG_Update_Date -gt $olderThanDate ) {
                $inScope=$False
            }

            if( $inScope -and $notinview -and $devInfo.SG_View_Count -gt 0 ) {
                $inScope=$False
            }
            
            if( $inScope ) {

                    if( $detail ) {
                        $devsInfo+=New-Object -TypeName PSObject -Property $devInfo
                    }

                    $total_Size_GB+=$devInfo.Size_GB
                    $total_Used_GB+=$devInfo.Used_GB

            }
        }

        $devsInfo+=New-Object -TypeName PSObject

        $devInfo=[ordered]@{}

        $devInfo.add( "DevName", "TOTAL:")
        $devInfo.add( "Size_GB", $total_Size_GB)
        $devInfo.add( "Used_GB", $total_Used_GB)

        if( $total_Size_GB -ne 0 ) { 
            $pct=100*$total_Used_GB/$total_Size_GB 
        } else { 
            $pct=0 
        } 

        $devInfo.add( "Used_Pct",$pct)
        $devInfo.add( "SG_Name","(VMAX $fullVMAXSID)")

        $devsInfo+=New-Object -TypeName PSObject -Property $devInfo

        Write-Progress -Activity "Analyzing $totalTDEVcount TDEV devices on VMAX $fullVMAXSID ..." -Completed -Status "All done."



        $devsInfo | ft DevName,
                       @{n="Size_GB";e={"{0:N0}" -f [long]$_.Size_GB};a="right"},
                       @{n="Used_GB";e={"{0:N0}" -f [long]$_.Used_GB};a="right"},
                       @{n="Used_%" ;e={"{0:N0}" -f [int]$_.Used_Pct};a="right"},
                       SG_Name,
                       #@{n="ViewCount";e={$_.SG_View_Count};a="right"},
                       SG_Update_Date, 
                       @{n="RDF" ;e={$_.RDF};a="center"},
                       @{n="Clone" ;e={$_.Clone};a="center"} -AutoSize


    }

    if( $help -or ! $SID ) {
        "Usage: vmax_tdev_allocation_report.ps1 -sid <SID1,SID2,...> [-insg|-notinsg] [-notinview] [-detail] [-mindevsize <n>] [-maxallocationpct <n>] -sgolderthandays <n>" 
        exit
    }

    if( $sgolderthandays ) {
        $insg=$True
    }

    "Computer: " + (hostname)
    "Script: " + $MyInvocation.MyCommand.Definition
    ""
    "Input parameters:"
    if( $insg )               { "  -insg" }
    if( $notinsg )            { "  -notinsg" }
    if( $notinview )          { "  -notinview" }
    if( $detail )             { "  -detail" }
    if( $mindevsize )         { "  -mindevsize $mindevsize" }
    if( $maxallocationpct )   { "  -maxallocationpct $maxallocationpct" }
    if( $sgolderthandays )    { "  -sgolderthandays $sgolderthandays" }
    ""
    (get-date).toString()
    ""

    foreach($vmaxsid in  $SID )
    {
        generateTDEVReport $vmaxsid $insg $notinsg $notinview $detail $mindevsize $maxallocationpct $sgolderthandays
        ""
    }
}





