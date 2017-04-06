<#

.SYNOPSIS
Health Check script for EMC VMAX2 and VMAX3

.DESCRIPTION
The script uses Solution Enabler (SE) commands to get VMAX 2 health check data: 
- hardware failures
- pool utilization
- RDF pair status

Parameters:

-SID <Symmetrix ID>            self explanatory
-sidlist <file>                   a text file containing list of SIDs one per line, lines starting with # are excluded

-capacity                      show storage capacity
-rdf                           show RDF pair state
-hw                            show H/W module status (excluding drives)
-hwfail                        show h/w failures
-login                         show initiator logins
-loginfail                     show initiator login failues only
-all                           all reports except for "-login" and "-hw"

.EXAMPLE

health_check_VMAX.ps1 -sidlist vmax_list.txt -hwfail -capacity
health_check_VMAX.ps1 -sid 4534 -hwfail -capacity

.NOTES


.LINK

#>

param(
    [string]$SID,
    [string]$sidlist,
    [switch]$hwfail,
    [switch]$hw,
    [switch]$capacity,
    [switch]$rdf,
    [switch]$login,
    [switch]$loginfail,
    [switch]$all
#    [switch]$unused_tdev    future plan
    
    
)

$VMAXLIST=@()
$UnknownSID=@()
$VMAXINFO=[ordered]@{}

if( $SID -ne "" ) {
    $VMAXLIST=$SID.split()
}

if( $sidlist -ne "" ) {
    if( test-path $sidlist ) {
        foreach( $SID in ( gc $sidlist | select-string -Pattern "^#|^$" -NotMatch )) {
            $VMAXLIST+=$SID
        }
    }
}   

if( $VMAXLIST.count -eq 0 ) {
    "Usage: health_check_VMAX.ps1 -SID <symm ID> | -sidlist <symm ID list file> [-all] [-hwfail|-hw] [-capacity] [-rdf] [-loginfail|login]"
    exit
}

"Computer: " + (hostname)
"Script: " + $MyInvocation.MyCommand.Definition
""

(get-date).ToString()
""

function getArrayBaseInfo {
   
   $env:SYMCLI_OUTPUT_MODE='XML'

   foreach( $sid in $VMAXLIST ) {

		$arrayInfo=[ordered]@{}

		[xml]$xmlOut=symcfg -sid $sid list -v
		
        if( $xmlOut -eq $null ) {
			$sid
			continue
		}
		                
    	$arrayInfo.SerialNumber		=$xmlOut.SymCLI_ML.Symmetrix.Symm_Info.Symid
		$arrayInfo.Model              =$xmlOut.SymCLI_ML.Symmetrix.Symm_Info.product_model
		$arrayInfo.EnginuityVersion   =$xmlOut.SymCLI_ML.Symmetrix.Enginuity.patch_level
		$arrayInfo.Cache              =$xmlOut.SymCLI_ML.Symmetrix.Cache.megabytes
	    $arrayInfo.PowerOn            =$xmlOut.SymCLI_ML.Symmetrix.Times.power_on
        
        $VMAXINFO.add($sid,(new-object -TypeName PSObject -Property $arrayInfo))
	}
	
} # End of getArrayBaseInfo


function removeUnknownSID {

	foreach( $sid in $UnknownSID ) {
		$VMAXLIST.remove($h)
	}
}

function hwReport {

    param(
        [switch]$failonly
    )

    $xmlNodeNameMap=@{ "SystemBay"="sys_bay_name";
                    "DriveBay" = "drive_bay_name";
    }

    $env:SYMCLI_OUTPUT_MODE='XML'

    if( $failonly ) {
        $reportTitle="== VMAX H/W Failures ================================================="
    } else {
        "== VMAX H/W Status Report (exluding drives) ================================================="
    }

    ""


    foreach( $sid in $VMAXINFO.keys ) {

        $sid=$VMAXINFO.$sid.SerialNumber
        
        [xml]$xmlout=symcfg -sid $sid list -env_data -v
#        [xml]$xmlout=(gc  "C:\Users\du82\Documents\Projects\2016-10-20 Health Check automation\symcfg-env_data-v.xml")
    
        "-- VMAX $sid -------------------------------------------------"
        ""
    
        $moduleStates=@()

    # SystemBay[sys_bay_name]->LED->Module                                            
    # SystemBay[sys_bay_name]->StandbyPowerSupplies->Module
    # SystemBay[sys_bay_name]->EnclosureSlot[enclosure_number]->Module                             <-Engines
    # SystemBay[sys_bay_name]->MatrixInterfaceBoardEnclosure[mibe_name]->Module
    # DriveBay[drive_bay_name]->StandbyPowerSupplies->Module
    # DriveBay[drive_bay_name]->Enclosure[enclosure_number]->Module

	   
        $xmlout.SelectNodes("//DriveBay|//SystemBay") | foreach { 

            $xmlBay=$_
            $bayName=$xmlBay.($xmlNodeNameMap[$xmlBay.name])

            foreach( $module in $xmlBay.LED.Module ) {
                if( -not $module ) {
                    continue
                }

                $moduleState=[ordered]@{}
                $moduleState.add("Bay",$bayName)
                $moduleState.add("Enclosure","LED")
                $moduleState.add("Module",$module.module_name)
                $moduleState.add("State",$module.module_state)

                $moduleStates+=New-Object -TypeName PSObject -Property $moduleState

            }

            foreach( $module in $xmlBay.EnclosureSlot.Module ) {
                $moduleState=[ordered]@{}
                $moduleState.add("Bay",$bayName)
                $moduleState.add("Enclosure","Engine " + $module.parentnode.enclosure_number)
                $moduleState.add("Module",$module.module_name)
                $moduleState.add("State",$module.module_state)

                $moduleStates+=New-Object -TypeName PSObject -Property $moduleState

            }

            foreach( $module in $xmlBay.Enclosure.Module ) {
                $moduleState=[ordered]@{}
                $moduleState.add("Bay",$bayName)
                $moduleState.add("Enclosure","Drive Enclosure " + $module.parentnode.enclosure_number )
                $moduleState.add("Module",$module.module_name)
                $moduleState.add("State",$module.module_state)

                $moduleStates+=New-Object -TypeName PSObject -Property $moduleState

            }

            foreach( $module in $xmlBay.StandbyPowerSupplies.Module ) {
                $moduleState=[ordered]@{}
                $moduleState.add("Bay",$bayName)
                $moduleState.add("Enclosure","SPS")
                $moduleState.add("Module",$module.module_name)
                $moduleState.add("State",$module.module_state)

                $moduleStates+=New-Object -TypeName PSObject -Property $moduleState

            }

            foreach( $module in $xmlBay.MatrixInterfaceBoardEnclosure.Module ) {
                if( -not $module ) {
                    continue
                }
                 
                $moduleState=[ordered]@{}
                $moduleState.add("Bay",$bayName)
                $moduleState.add("Enclosure", $module.parentnode.mibe_name )
                $moduleState.add("Module",$module.module_name)
                $moduleState.add("State",$module.module_state)

                $moduleStates+=New-Object -TypeName PSObject -Property $moduleState

            }

            foreach( $MIBE in $xmlBay.MatrixInterfaceBoardEnclosure ) {
                $moduleState=[ordered]@{}
                $moduleState.add("Bay",$bayName)
                $moduleState.add("Enclosure", $MIBE.mibe_name )
                $moduleState.add("Module", "N/A")
                $moduleState.add("State",$MIBE.mibe_state )

                $moduleStates+=New-Object -TypeName PSObject -Property $moduleState

            }

            
        }

        if( $failonly ) {
            "Failed Modules:"
            "---------------"

            $moduleStates | Where-Object -Property State -Match "Failed"  
            ""

            "Failed Drives:"
            "--------------"
            #DEBUG   [xml]$symdisk=(gc  "C:\Users\du82\Documents\Projects\2016-10-20 Health Check automation\symdisk-2638-failed.txt")
            [xml]$xmlout=(symdisk -sid $sid list -v -failed)
            if( $xmlout.SelectNodes('//Failed_Disk') ) {
                $xmlout.SelectNodes('//Disk_Info') | ft ident,interface,tid,disk_group_name,vendor,technology,rated_gigabytes,serial -autosize | out-string -Width 150
            }
        } else {
            $moduleStates
        }

       ""
    }
}

function storagePoolReport {
    param(
        [string]$sid
    )

    $pools=@()


    [xml]$xmlout=symcfg -sid $sid -pool -thin -gb -detail list


    $xmlout.selectnodes('//DevicePool') | sort pool_name | foreach {

        $poolInfo=[ordered]@{}

        $poolInfo."Pool Name"   =$_.pool_name
        $poolInfo.Technology    =$_.technology
        $poolInfo.DevConfig     =$_.dev_config
        $poolInfo.TotalTB       =$_.total_tracks_tb
        $poolInfo.UsedTB        =$_.total_used_tracks_tb
        $poolInfo.FreeTB        =$_.total_free_tracks_tb
        $poolInfo.UsedPCT       =$_.percent_full
        $poolInfo.SubscribedTB  =[int]$_.total_tracks_tb * ([int]$_.subs_percent/100)
        $poolInfo.SubscribedPCT =$_.subs_percent

        $pools+=New-Object -TypeName PSObject -Property $poolInfo
        
    }

    $pools+=New-Object -TypeName PSObject 

    $xmlTotals=$xmlout.SymCLI_ML.Symmetrix.Totals
      
    $poolInfo=[ordered]@{}

    $poolInfo."Pool Name"   ="TOTAL:"
    $poolInfo.Technology    =""
    $poolInfo.DevConfig     =""
    $poolInfo.TotalTB       =$xmlTotals.total_tracks_tb
    $poolInfo.UsedTB        =$xmlTotals.total_used_tracks_tb
    $poolInfo.FreeTB        =$xmlTotals.total_free_tracks_tb
    $poolInfo.UsedPCT       =$xmlTotals.percent_full
    $poolInfo.SubscribedTB  =[int]$xmlTotals.total_tracks_tb * ( [int]$xmlTotals.subs_percent/100)
    $poolInfo.SubscribedPCT =$xmlTotals.subs_percent

    $pools+=New-Object -TypeName PSObject -Property $poolInfo


    $pools | ft "Pool Name",Technology,DevConfig,
            @{n="Total TB";e={ "{0:N0}" -f [int]$_.TotalTB };a="right"},
            @{n="Used TB"; e={ "{0:N0}" -f [int]$_.UsedTB };a="right"},
            @{n="Free TB"; e={ "{0:N0}" -f [int]$_.FreeTB };a="right"},
            @{n="Used %"; e={ "{0:N0}" -f [int]$_.UsedPCT };a="right"},
            @{n="Subscr TB"; e={ "{0:N0}" -f [int]$_.SubscribedTB };a="right"},
            @{n="Subscr %"; e={ "{0:N0}" -f [int]$_.SubscribedPCT };a="right"} -AutoSize

}

function SRPReport {

    param(
        [string]$sid
    )

    $srps=@()


    [xml]$xmlout=symcfg -sid $sid -srp -detail list


    $xmlout.selectnodes('//SRP_Info') | sort name | foreach {

        $srpInfo=[ordered]@{}

        $srpInfo.SRP_Name      =$_.name
        $srpInfo.TotalTB       =$_.usable_capacity_terabytes
        $srpInfo.UsedTB        =$_.allocated_capacity_terabytes
        $srpInfo.FreeTB        =$_.free_capacity_terabytes
        $srpInfo.UsedPCT       =[int]$_.allocated_capacity_terabytes*100/[int]$_.usable_capacity_terabytes
        $srpInfo.SubscribedTB  =$_.subscribed_capacity_terabytes
        $srpInfo.SubscribedPCT =$_.subscribed_capacity_pct

        $srps+=New-Object -TypeName PSObject -Property $srpInfo
        
        
    }

    $srps+=New-Object -TypeName PSObject 

    $xmlTotals=$xmlout.SymCLI_ML.Symmetrix.SRP.SRP_Totals
      
    $srpInfo=[ordered]@{}

    $srpInfo.SRP_Name   = "TOTAL:"
    $srpInfo.TotalTB       =$xmlTotals.total_usable_capacity_terabytes
    $srpInfo.UsedTB        =$xmlTotals.total_allocated_capacity_terabytes
    $srpInfo.FreeTB        =$xmlTotals.total_free_capacity_terabytes
    $srpInfo.UsedPCT       =[int]$xmlTotals.total_allocated_capacity_terabytes * 100 / [int]$xmlTotals.total_usable_capacity_terabytes
    $srpInfo.SubscribedTB  =$xmlTotals.total_subscribed_capacity_terabytes
    $srpInfo.SubscribedPCT =$xmlTotals.total_subscribed_capacity_pct

    $srps+=New-Object -TypeName PSObject -Property $srpInfo

    $srps | ft SRP_Name,
            @{n="Total TB";e={ "{0:N0}" -f [int]$_.TotalTB };a="right"},
            @{n="Used TB"; e={ "{0:N0}" -f [int]$_.UsedTB };a="right"},
            @{n="Free TB"; e={ "{0:N0}" -f [int]$_.FreeTB };a="right"},
            @{n="Used %"; e={ "{0:N0}" -f [int]$_.UsedPCT };a="right"},
            @{n="Subscr TB"; e={ "{0:N0}" -f [int]$_.SubscribedTB };a="right"},
            @{n="Subscr %"; e={ "{0:N0}" -f [int]$_.SubscribedPCT };a="right"} -AutoSize

}

function storageCapacityReport {
    $env:SYMCLI_OUTPUT_MODE='XML'
    
    "== VMAX Pool Capacity ====================================================="
    ""
       
    foreach( $sid in $VMAXINFO.keys ) {

        $version=$VMAXINFO.$sid.EnginuityVersion

        $sid=$VMAXINFO.$sid.SerialNumber
        
        "-- VMAX $sid -------------------------------------------------"
        ""

        if( $version -like "59*" ) {
            SRPReport $sid
        }

        storagePoolReport $sid
        
   }

}

function rdfReport {

    $env:SYMCLI_OUTPUT_MODE='XML'
    
    "== VMAX RDF Group Pair Status ================================================="
    ""
    
    foreach( $sid in $VMAXINFO.keys ) {

        $sid=$VMAXINFO.$sid.SerialNumber

        [xml]$symrdf=symrdf -sid $sid -rdfg all list
        [xml]$symcfg=symcfg -sid $sid -rdfg all list
        
        "-- VMAX $sid -------------------------------------------------"
        ""
        "{0,5} {1,-16} {2,-20}" -f "RDFG#","RDF Group Label", "RDF group pair state:device count"
        "{0,5} {1,-16} {2,-20}" -f ("-"*5), ("-"*16),("-"*20)

        $rdfg_names=@{}
        
        foreach( $rdfg in $symcfg.selectnodes('//RdfGroup') ) {
            $rdfg_names[$rdfg.ra_group_num]=$rdfg.ra_group_label
            #$rdfg.ra_group_label
        }
        
        $rdfgs=@{}
        foreach( $dev in $symrdf.selectnodes('//Device') ) { 
            
            if( $dev.RDF.RDF_Info.r1_invalids -ne "N/A" ) {
             
                $rdfg=$dev.RDF.Local.ra_group_num
            
                if( -not $rdfgs[$rdfg] ) {
                    $rdfgs[$rdfg]=@{}
                }
                $rdfgs[$rdfg][$dev.RDF.RDF_Info.pair_state]++
            }
        }
        
        foreach( $rdfg in $rdfgs.keys | Sort-Object @{e={$_ -as [int]}} ) {
            $str="{0,5} {1,-16} " -f $rdfg,$rdfg_names[$rdfg]
            
            $pair_states=$rdfgs[$rdfg]
            
            foreach( $pair_state in $pair_states.keys | sort ) {
                $num=$pair_states[$pair_state]
                $str+="$pair_state" +":" + $pair_states[$pair_state] + " "
                
            }
            $str
        }
        ""
    }

}

function initiatorReport {

    param(
        [switch]$failonly
    )
    
    $env:SYMCLI_OUTPUT_MODE='XML'
       
    if( $failonly ) {
        $reportTitle="== VMAX Initiator Login Failure Report ================================================="
    } else {
        "== VMAX Initiator Login Report ================================================="
    }
    
    $reportTitle
    ""
        
    foreach( $SID in $VMAXINFO.keys ) {

        $sid=$VMAXINFO.$sid.SerialNumber

        "-- VMAX $sid -------------------------------------------------"
        ""
     
        [xml]$symaccessMaskingViewXmlOut=symaccess -sid $SID list view -detail
        [xml]$symaccessLoginsXmlOut=symaccess -sid $SID list logins
        
<# DEBUG
        [xml]$symaccessMaskingViewXmlOut=cat  symaccess-list-view-detail.xml
        [xml]$symaccessLoginsXmlOut=cat  symaccess-list-logins.xml
End of DEBUG #>

                
        $initiatorLogins=@{}
        
        $symaccessLoginsXmlOut.SelectNodes("//Devmask_Login_Record") | foreach {
            
            $xmlLoginRecord=$_

            $port=($xmlLoginRecord.director -replace "FA-") + ":" + $xmlLoginRecord.port

            foreach( $login in $xmlLoginRecord.Login ) { 

                #$loginInfo=@{}

                $wwn=$login.originator_port_wwn

                #$loginInfo.Port=$port
                #$loginInfo.LoggedIn=$login.logged_in

                if( -not $initiatorLogins[$wwn] ) {
                    $initiatorLogins.add($wwn, @{} )
                }

                $initiatorLogins[$wwn].add($port,$login.logged_in)
            }
        }
       

        $initiatorGroups=@{}

        $symaccessMaskingViewXmlOut.selectnodes('//Masking_View') | foreach {
            
            $xmlMaskingView=$_.View_Info
            
            $initiatorGroupName=$xmlMaskingView.init_grpname -replace ' \*'

            if( -not $initiatorGroups[$initiatorGroupName] ) {

                $ports=@{}

                foreach( $port_info in $xmlMaskingView.port_info.Director_Identification ) {
                    
                    $ports.add(($port_info.dir  -replace "FA-") + ":" + $port_info.port,$false)
                }

                # DEBUG "New init group: $initiatorGroupName"

                $initiators=@()

                foreach ( $initiator in $xmlMaskingView.Initiator_List.Initiator ) {

                    if( $initiator.wwn ) {

                        $initiatorInfo=[ordered]@{}
                    
                        #DEBUG "New WWN: " + $initiator.wwn

                        $initiatorInfo.WWPN     = $initiator.wwn
                        $initiatorInfo.LoggedIn = $false
                        
                        #May be needed in the future # $initiatorInfo.Alias   = $initiator.user_node_name+"/"+ $initiator.user_port_name

                        
                        foreach( $port in $ports.keys | sort @{ e={ $_ -replace "\D.*" -as [int] } },@{ e={$_ -replace "\d" } } ) { 
                            if( $initiatorLogins[$initiator.wwn].$port -eq "Yes" ) { 
                                $initiatorInfo.$port   = '*'
                                $initiatorInfo.LoggedIn = $true
                                $ports[$port]=$true
                            } else {
                                $initiatorInfo.$port   = ''
                            }
                        }

                        $initiators+=New-Object -TypeName PSObject -Property $initiatorInfo
                    }
                }


                if( $initiators.count -gt 0 ) {

                    if( $failonly ) {

                        $loggedInCount=0
                        $portsLoggedIn=0
                    
                        foreach( $init in $initiators ) {
                
                            if( $init.LoggedIn ) { $loggedInCount++ }
                    
                        }

                        foreach( $port in $ports.keys ) {
                        
                            if( $ports[$port] ) {
                                $portsLoggedIn++
                            }
                        }

                        if( $portsLoggedIn -ne $ports.count ) {

                            #DEBUG $initiatorGroupName + " Ports " + $ports.count + " LoggedIn $portsLoggedIn"

                            $initiatorGroups.add($initiatorGroupName,$initiators)

                        } elseif ( $loggedInCount -ne $initiators.count -and $initiators.count / $loggedInCount -ne 2 ) {

                            #DEBUG $initiatorGroupName + " Initiators: " + $initiators.count + " LoggedIn Count: $loggedInCount "
                            $initiatorGroups.add($initiatorGroupName,$initiators)
                        
                        } 

                    } else {
                        $initiatorGroups.add($initiatorGroupName,$initiators)
                    }
                }

            }

        }

        foreach( $initiatorGroupName in ($initiatorGroups.keys | sort)  ) {
            
            "-" * 60
            "Initiator Group: $initiatorGroupName (VMAX " + $sid + ")"

            $initiatorGroups[$initiatorGroupName] | Select-Object -ExcludeProperty portCount |  ft -AutoSize 

        }



    } # End of VMAX loop        
     
}

$originalSymCliOutputMode=$env:SYMCLI_OUTPUT_MODE


getArrayBaseInfo

"== VMAX Health Check Inventory =============================================================="
$VMAXINFO.values | ft -AutoSize 	SerialNumber,Model,EnginuityVersion,
						@{ n="Cache (MB)"; e={ "{0:N0}" -f [int]$_.Cache };a="Right" },
						PowerOn

if( $hwfail -or $all ) {
    hwReport -failonly
}

if( $hw ) {
    hwReport
}


if( $capacity -or $all ) {    
    storageCapacityReport
}

if( $loginfail -or $all ) {
    initiatorReport -failonly
}

if( $rdf -or $all ) {
    rdfReport
}

if( $login ) {
    initiatorReport
}

$env:SYMCLI_OUTPUT_MODE=$originalSymCliOutputMode
