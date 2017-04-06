#!/usr/bin/perl

# naviseccli -h APM00133419283 storagepool -list -availableCap -userCap
#Pool Name:  Silver Pool-1
#Pool ID:  0
#User Capacity (Blocks):  57399791616
#User Capacity (GBs):  27370.354
#Available Capacity (Blocks):  10247786496
#Available Capacity (GBs):  4886.525

use Getopt::Std;

getopts( 'h:' );

if( $opt_h eq "" ) {
        print "vnx_pool_totals.pl -h <ip>\n";
        exit 1;
}

open( STORAGEPOOL, "naviseccli -h $opt_h storagepool -list -availableCap -userCap |") or die "Can't run navisecli";
#open( STORAGEPOOL,"cat ../tmp/storagepool.o|")  or die "Can't run navisecli";

while( <STORAGEPOOL> ) {
	chomp;

	if( /Pool Name/ ) {
		$poolname = (split ':')[1];
		$poolname =~ s/^\s+|\s+$//g;
	}

	if( /User Capacity \(GB/ ) {
		$pools{$poolname}{usercapacity}=(split ':')[1];
	}

	if( /Available Capacity \(GB/ ) {
		$pools{$poolname}{availablecapacity}=(split ':')[1];
	}
}

printf "%-25s%20s%20s\n", "Pool Name","User Capacity", "Available Capacity";

foreach my $poolname ( sort keys %{pools} ) {
	printf "%-25s%20d%20d\n",$poolname,$pools{$poolname}{usercapacity},,$pools{$poolname}{availablecapacity};
}
