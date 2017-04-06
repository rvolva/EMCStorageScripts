BASEDIR=`dirname $0`
NAVICLI=/opt/Navisphere/bin/naviseccli

cat $BASEDIR/vnxlist.txt | while read sn ip model family site; 
do 
	echo "$sn $model $ip"
	$NAVICLI -h $ip faults -list
	case $family in
		VNX1|CX) $NAVICLI -h $ip getcache -state
				;;
		VNX2) $NAVICLI -h $ip cache -sp -info -state
				;;
	esac
done
