#!/usr/bin/ksh

## $Date: 2012/01/17 18:12:05 $
## $Revision: 1.3 $
##
## Vlad Pavlov
##

# This script print list of EMC arrays the host is attached to

# The script rely on inq utility presense on the server or a netwrork share

INQ_LOCATIONS="/usr/global/bin/inq /usr/local/bin/inq $(whence inq)"

for loc in $INQ_LOCATIONS; do

	if [[ -x $loc ]]; then
		INQ=$loc
		break
	fi
done

if [[ -z $INQ ]]; then
	print -u2 "ERROR: coudn't find inq utility"
	print UNKNOWN
	exit 1
fi

CX_LIST=$( $INQ -nodots -clar_wwn | grep ^/dev | sort -bu -k 2,2 | awk '{ printf "%s,", $2 }' )
SYM_LIST=$( $INQ -nodots -sym_wwn | grep ^/dev | sort -bu -k 2,2 | awk '{ printf "%s,", $2 }'  )

CX_LIST=${CX_LIST%,}
SYM_LIST=${SYM_LIST%,}

if [[ -n $CX_LIST ]]; then
	OUTPUT="CX:$CX_LIST;"
fi

if [[ -n $SYM_LIST ]]; then
	OUTPUT="${OUTPUT}SYM:$SYM_LIST"
fi

if [[ -z $OUTPUT ]]; then
	OUTPUT="NO_EMC_STORAGE_CONNECTED"
fi

print $OUTPUT
