<#

.SYNOPSIS

Health Check script for EMC VMAX2 and VMAX3

.DESCRIPTION

The script uses Solution Enabler (SE) commands to fetch required data: 

.PARAMETER SID

Symmetrix ID

.PARAMETER inventory

Show array inventory (model, serial number)

.PARAMETER capacity

Storage capacity

.PARAMETER rdf

RDF group state


.PARAMETER hw

Hardware module status (excluding drives)

.PARAMETER hwfail

Hardware failures

.PARAMETER initlogin

Initiator login status

.PARAMETER initloginissues

Initiator logins with issues

.PARAMETER all

All reports except for "-initlogin" and "-hw"

.EXAMPLE

PS> vmax_health_check.ps1 -sid 2343,2343 -all

.EXAMPLE

PS> vmax_health_check.ps1 -sid 4534 -hwfail -capacity -inventory

.NOTES


.LINK

#>

[CmdletBinding(DefaultParameterSetName="Help")]
param(
    [Parameter(Mandatory=$true,Position=0,ParameterSetName="Switches")]
    [Parameter(Mandatory=$true,Position=0,ParameterSetName="ALL")]
    [string[]]$SID,

    [Parameter(ParameterSetName="Switches")]
    [switch]$inventory,

    [Parameter(ParameterSetName="Switches")]
    [switch]$hwfail,

    [Parameter(ParameterSetName="Switches")]
    [switch]$hw,

    [Parameter(ParameterSetName="Switches")]
    [switch]$capacity,

    [Parameter(ParameterSetName="Switches")]
    [switch]$rdf,

    [Parameter(ParameterSetName="Switches")]
    [switch]$initlogin,

    [Parameter(ParameterSetName="Switches")]
    [switch]$initloginissues,
    
    [Parameter(Mandatory=$true,ParameterSetName="ALL")]
    [Alias("a")]
    [switch]$all,

    [Parameter(ParameterSetName="Help")]
    [Alias("h")]
    [switch]$Help

)

$VERSION="6.9"

$VMAXINFO=[ordered]@{}

function printHeader( [string]$header, [string]$sid="" ) {

    if( $sid -ne "" ) {
        $array="SID: $sid "
    } 

    ("== $array" + "$header ").PadRight( 90, "=" )
    ""
}

function getArrayBaseInfo {
   
   $env:SYMCLI_OUTPUT_MODE='XML'

   foreach( $sid in $SID ) {

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


function hwReport {

    param(
        [switch]$failonly
    )

    $xmlNodeNameMap=@{ "SystemBay"="sys_bay_name";
                    "DriveBay" = "drive_bay_name";
    }

    $env:SYMCLI_OUTPUT_MODE='XML'

    if( $failonly ) {
        $header="HARDWARE FAILURES"
    } else {
        $header = "HARDWARE STATUS REPORT (exluding drives)"
    }

    foreach( $sid in $VMAXINFO.keys ) {

        $sid=$VMAXINFO.$sid.SerialNumber
        
        [xml]$xmlout=symcfg -sid $sid list -env_data -v
    
        printHeader $header $sid
    
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

            $moduleStates | Where-Object -Property State -Match "Failed"  | ft -AutoSize
            ""

            "Failed Drives:"
            "--------------"
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

        $poolInfo.PoolName      =$_.pool_name
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

    $poolInfo.PoolName      ="TOTAL:"
    $poolInfo.Technology    =""
    $poolInfo.DevConfig     =""
    $poolInfo.TotalTB       =$xmlTotals.total_tracks_tb
    $poolInfo.UsedTB        =$xmlTotals.total_used_tracks_tb
    $poolInfo.FreeTB        =$xmlTotals.total_free_tracks_tb
    $poolInfo.UsedPCT       =$xmlTotals.percent_full
    $poolInfo.SubscribedTB  =[int]$xmlTotals.total_tracks_tb * ( [int]$xmlTotals.subs_percent/100)
    $poolInfo.SubscribedPCT =$xmlTotals.subs_percent

    $pools+=New-Object -TypeName PSObject -Property $poolInfo

    $pools | ft @{n="Pool Name"; e={ "{0,-15}" -f $_.PoolName} },
                @{n="Technology"; e={ "{0,-10}" -f $_.Technology } },
                @{n="DevConfig"; e={ "{0,-12}" -f $_.DevConfig } },
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

    $srps | ft  @{n="SRP Name";e={ "{0,-39}" -f $_.SRP_Name }},
                @{n="Total TB";e={ "{0:N0}" -f [int]$_.TotalTB };a="right"},
                @{n="Used TB"; e={ "{0:N0}" -f [int]$_.UsedTB };a="right"},
                @{n="Free TB"; e={ "{0:N0}" -f [int]$_.FreeTB };a="right"},
                @{n="Used %"; e={ "{0:N0}" -f [int]$_.UsedPCT };a="right"},
                @{n="Subscr TB"; e={ "{0:N0}" -f [int]$_.SubscribedTB };a="right"},
                @{n="Subscr %"; e={ "{0:N0}" -f [int]$_.SubscribedPCT };a="right"} -AutoSize

}

function storageCapacityReport {
    $env:SYMCLI_OUTPUT_MODE='XML'
    
    foreach( $sid in $VMAXINFO.keys ) {

        $version=$VMAXINFO.$sid.EnginuityVersion

        $sid=$VMAXINFO.$sid.SerialNumber
        
        printHeader "POOL CAPACITY" $sid

        if( $version -like "59*" ) {
            SRPReport $sid
        }

        storagePoolReport $sid
        
    }

    

}

function rdfReport {

    $env:SYMCLI_OUTPUT_MODE='XML'
    
    foreach( $sid in $VMAXINFO.keys ) {

        $sid=$VMAXINFO.$sid.SerialNumber

        [xml]$symrdf=symrdf -sid $sid -rdfg all list
        [xml]$symcfg=symcfg -sid $sid -rdfg all list
        
        printHeader "RDF GROUP STATUS" $sid
        
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

                $pair_state=$dev.RDF.RDF_Info.pair_state

                if( $pair_state -in @("Split","Suspended","SyncInProg") ) {

                    $pair_state+=" "+([datetime]::ParseExact($dev.RDF.Status.link_status_change_time,"ddd MMM dd HH:mm:ss yyyy",$null) | get-date -format g) #.ToShortDateString()
                
                }

                $rdfgs[$rdfg][$pair_state]++
            }
        }
        
        foreach( $rdfg in $rdfgs.keys | Sort-Object @{e={$_ -as [int]}} ) {

            $str="{0,5} {1,-16} " -f $rdfg,$rdfg_names[$rdfg]
            
            $pair_states=$rdfgs[$rdfg]
            
            foreach( $pair_state in $pair_states.keys | sort ) {

                $num=$pair_states[$pair_state]
                $str+="$pair_state" +" - " + $pair_states[$pair_state] + ", "
                
            }

            $str=$str -replace ", $",""
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
        $header = "INITIATOR GROUPS WITH LOGIN ISSUES"
    } else {
        $header = "INITIATOR GROUP LOGIN STATUS"
    }
    
    foreach( $SID in $VMAXINFO.keys ) {

        $sid=$VMAXINFO.$sid.SerialNumber

        printHeader $header $sid
     
        [xml]$symaccessMaskingViewXmlOut=symaccess -sid $SID list view -detail
        [xml]$symaccessLoginsXmlOut=symaccess -sid $SID list logins
        
               
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

                $initiators=@()

                foreach ( $initiator in $xmlMaskingView.Initiator_List.Initiator ) {

                    if( $initiator.wwn ) {

                        $initiatorInfo=[ordered]@{}
                    
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

                            $initiatorGroups.add($initiatorGroupName,$initiators)

                        } elseif ( $loggedInCount -ne $initiators.count -and $initiators.count / $loggedInCount -ne 2 ) {

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

if ( $PsCmdlet.ParameterSetName -eq "Help" )
{
    get-help $script:MyInvocation.MyCommand.Definition
    exit 1
}

$originalSymCliOutputMode=$env:SYMCLI_OUTPUT_MODE


"Computer: " + (hostname)
"Script: " + $MyInvocation.MyCommand.Definition
"Version: " + $VERSION
""

(get-date).ToString()
""

getArrayBaseInfo

if( $inventory -or $all ) {

    printHeader "VMAX ARRAY INVENTORY"
    $VMAXINFO.values | ft -AutoSize 	SerialNumber,Model,EnginuityVersion,
						    @{ n="Cache (MB)"; e={ "{0:N0}" -f [int]$_.Cache };a="Right" },
						    PowerOn
}

if( $hwfail -or $all ) {
    hwReport -failonly
}

if( $hw ) {
    hwReport
}


if( $capacity -or $all ) {    
    storageCapacityReport
}

if( $initloginissues -or $all ) {
    initiatorReport -failonly
}

if( $rdf -or $all ) {
    rdfReport
}

if( $initlogin ) {
    initiatorReport
}

$env:SYMCLI_OUTPUT_MODE=$originalSymCliOutputMode
