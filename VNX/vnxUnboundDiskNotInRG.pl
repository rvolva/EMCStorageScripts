#!/usr/bin/perl

#Bus 1 Enclosure 1  Disk 10
#Raid Group ID:           6
#Drive Type:              NL SAS
#Type:                    28: RAID6 29: RAID6 30: RAID6 31: RAID6
#State:                   Enabled
#Capacity:                2817564
#User Capacity:           2062.097168

use Getopt::Std;

getopts( 'h:' );

if( $opt_h eq "" ) {
        print "vnxrgcap.pl -h <ip>\n";
        exit 1;
}

open( GETRG, "naviseccli -h $opt_h getdisk -rg -drivetype -type -state -capacity -usercapacity|") or die "Can't run navisecli";
#open( GETRG, "cat o.683|") or die "Can't run navisecli";

while( <GETRG> ) {

        chomp;

        if( /Drive Type/ ) {
                $devtype = (split ':')[1]; 
		$devtype =~ s/^\s+|\s+$//g;
		$devtype =~ s/\s+/_/g;
        }

#        if( /Hot Spare/ ) {
#		$hotspate="hotspare";
#        }

        if( /^State/ ) {
                $state = (split ':')[1]; 
		$state =~ s/^\s+|\s+$//g;
		$state =~ s/\s+/_/g;
        }

        if( /^Bus/ ) {
		$devloc=$_;
		$devloc =~ s/^\s+|\s+$//g;
		$devloc =~ s/\s+/_/g;
        }

	if( /Raid Group ID/ ) {
                $rg = (split ':')[1]; 
		$rg =~ s/^\s+|\s+$//g;
		$rg =~ s/\s+/_/g;
	}

        if( /^Capacity/ ) {
		$devcapacity = (split ':')[1];
		printf "%-30s%-15s%-45s%-17s%15.2f\n",$devloc, $devtype, $rg, $state, $devcapacity/1024,"\n";
		if( $rg =~ "not_belong_to_a_RAIDGroup" ) {
			$devtypes{$devtype}{capacity}+=$devcapacity/1024;
		}
        }

}

printf "\n%-15s%-45s%15s\n","Disk_Type","RG","Total_Capacity";

foreach my $devtype ( keys %{devtypes} ) {
	printf "%-15s%-45s%15.2f\n",$devtype, "This_disk_does_not_belong_to_a_RAIDGroup", $devtypes{$devtype}{capacity};
}
