cat vnxlist.txt | while read sn ip model family site; 
do 
	echo "$sn $model $ip"
	naviseccli -h $ip getdisk -drivetype -rev
#	case $family in
#		VNX1) naviseccli -h $ip getcache -state
#				;;
#		VNX2) naviseccli -h $ip cache -sp -info -state
#				;;
#	esac
done
