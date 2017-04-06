#!/usr/bin/perl -l /usr/share/perl5

use Getopt::Std;

getopts( 's:g:' );

if( $opt_s eq "" ) {
        print "vmax_fa_logins.pl -s <VMAX SID> -g <storage group>\n";
        exit 1;
}

#open(SYMDEV,"cat symdev.txt|") or die "Can't run symaccess";
open(SYMDEV,"symdev -sid $opt_s list -v -sg $opt_g|") or die "Can't run symdev";

while( <SYMDEV> ) {
	chomp;

	if( /^    Device Symmetrix Name/ ) {
		printf "\n";
		$symdev = (split ':')[1];
		$symdev =~ s/^\s+|\s+$//g;
		printf "%4s ",$symdev;
#		if( $symdev != "" ) {
#			printf "%4s %4s %6s %5s   %4s %4s %6s %12s %22s %22s %22s\n", $sourcedev,\
#			printf "%4s %4s\n", $sourcedev,$clonedev;
#				$clonestate,\
#				$clonepct,\
#				$sourcedev,\
#				$r2dev,\
#				$rdfgroup,\
#				$remotevmax,\
#				$rdfmode,\
#				$r1state,\
#				$r2state,\
#				$rdfpairstate;
#
			$clonedev="";
 			$clonestate="";
			$clonepct="";
			$sourcedev="";
			$r2dev="";
			$rdfgroup="";
			$remotevmax="";
			$rdfmode="";
			$r1state="";
			$r2state="";
			$rdfpairstate="";
#		}

#		$symdev = (split ':')[1];
#		$symdev =~ s/^\s+|\s+$//g;

	}

#	if( /Source \(SRC\) Device Symmetrix Name/ ) {
#		$sourcedev = (split ':')[1];
#		$sourcedev =~ s/^\s+|\s+$//g;
#		printf "%4s ",$sourcedev;
#	}

	if( /Target \(TGT\) Device Symmetrix Name/ ) {
		$clonedev=(split ':')[1];
		$clonedev =~ s/^\s+|\s+$//g;
#		printf "%4s ",$clonedev;
	}

	if( /State of Session \(SRC/ ) {
		$clonestate=(split)[1];
		$clonestate =~ s/^\s+|\s+$//g;
	}

	if( /Percent Copied/ ) {
		$clonepct=(split ':')[1];
		$clonepct =~ s/^\s+|\s+$//g;
	}

	if( /Remote Device Symmetrix Name/ ) {
		$r2dev = (split ':')[1];
		$r2dev =~ s/^\s+|\s+$//g;
		printf "%4s %4s %4s ",$clonedev,$symdev,$r2dev;
	}

	if( /RDF \(RA\) Group Number/ ) {
		$rdfgroup = (split)[1];
		$rdfgroup =~ s/^\s+|\s+$//g;
	}

	if( /Remote Symmetrix ID/ ) {
		$remotevmax = (split)[1];
		$remotevmax =~ s/^\s+|\s+$//g;
	}

	if( /RDF Mode/ ) {
		$rdfmode = (split)[1];
		$rdfmode =~ s/^\s+|\s+$//g;
#		printf "%s ", $rdfmode;
	}

	if( /Device RDF State/ ) {
		$r1state = (split)[1];
		$r1state =~ s/^\s+|\s+$//g;
	}

	if( /Remote Device RDF State/ ) {
		$r2state = (split)[1];
		$r2state =~ s/^\s+|\s+$//g;
	}

	if( /RDF Pair State \(  R1/ ) {
		$rdfpairstate = (split)[1];
		$rdfpairstate =~ s/^\s+|\s+$//g;
	}

}

printf "\n";
