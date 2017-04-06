#!/usr/bin/perl

use Getopt::Std;

getopts( 's:' );

if( $opt_s eq "" ) {
        print "vmax_fa_logins.pl -s <VMAX SID>\n";
        exit 1;
}

#open(FALOGINS,"cat /home/vpavlov/projects/2016/vmax3512/entprdcgy005/vmax2278.logins.txt|") or die "Can't run symaccess";
open(FALOGINS,"symaccess -sid $opt_s list logins|") or die "Can't run symaccess";

while( <FALOGINS> ) {
	chomp;

	if( /Director Identification/ ) {
		$dir = (split ':')[1];
		$dir =~ s/^\s+|\s+$//g;
	}

	if( /Director Port/ ) {
		$dirport=(split ':')[1];
		$dirport =~ s/^\s+|\s+$//g;
		printf "\n%6s:%s ", $dir, $dirport;
	}


	if( /Fibre/ ) {
		$node=(split)[2];
		$loggedin=(split)[5];
		if( $loggedin eq "Yes" ) {
			printf "%s ", $node;
		}
	}
}

printf "\n";
