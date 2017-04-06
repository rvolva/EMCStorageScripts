#!/usr/bin/perl

#RaidGroup ID:                              11
#Drive Type:                                SAS
#RaidGroup Type:                            r5
#Raw Capacity (Blocks):                     15459618816
#Logical Capacity (Blocks):                 13741883392
#Free Capacity (Blocks,non-contiguous):     428490752

use Getopt::Std;

$VNXBLOCKSIZE=2048;

getopts( 'h:' );

if( $opt_h eq "" ) {
        print "vnxrgcap.pl -h <ip>\n";
        exit 1;
}

open( GETRG, "naviseccli -h $opt_h getrg -drivetype -type -tcap -ucap|") or die "Can't run navisecli";
#open( GETRG, "cat rg.o|") or die "Can't run navisecli";

while( <GETRG> ) {

        chomp;

        if( /RaidGroup ID/ ) {
                $rgid = (split ':')[1]; 
        }

        if( /Drive Type/ ) {
                $drivetype = (split ':')[1]; 
		$drivetype =~ s/^\s+|\s+$//g;
		$drivetype =~ s/\s+/_/g;
		$rgs{$rgid}{drivetype}=$drivetype;
        }

        if( /RaidGroup Type/ ) {
		$rgt=(split ':')[1];
		$rgt =~ s/^\s+|\s+$//g;
		$rgt =~ s/\s+/_/g;
		$rgs{$rgid}{rgt}=$rgt
        }

        if( /Logical Capacity/ ) {
                $lcap = (split ':')[1]/$VNXBLOCKSIZE/1024; 
		$rgs{$rgid}{lcap}=$lcap;
        }

        if( /Free Capacity/ ) {
                $fcap = (split ':')[1]/$VNXBLOCKSIZE/1024; 
		$rgs{$rgid}{fcap}=$fcap;
        }

}

printf "%-5s%-15s%-10s%15s%15s\n","RG#","DriveType","RAID_Type","Total_Cap_GB","Free_Cap_GB";

foreach my $rgid ( sort {$a <=> $b} keys %{rgs} ) {

	$rgt=$rgs{$rgid}{rgt};
	$drivetype=$rgs{$rgid}{drivetype};
	$lcap=$rgs{$rgid}{lcap};
	$fcap=$rgs{$rgid}{fcap};

	printf "%-5d%-15s%-10s%15.2f%15.2f\n",$rgid,$drivetype,$rgt,$lcap,$fcap;

	$drivetypes{$drivetype}{$rgt}{lcap}+=$lcap;
	$drivetypes{$drivetype}{$rgt}{fcap}+=$fcap;
}

printf "\n%-15s%-10s%15s%15s\n","DriveType","RAIDType","Total_Cap_GB","Free_Cap_GB";

foreach my $drivetype ( sort keys %{drivetypes} ) {
	foreach my $rgt ( sort keys %{$drivetypes{$drivetype}} ) {
		printf "%-15s%-10s%15.2f%15.2f\n",$drivetype,$rgt,$drivetypes{$drivetype}{$rgt}{lcap},$drivetypes{$drivetype}{$rgt}{fcap};
	}
}
