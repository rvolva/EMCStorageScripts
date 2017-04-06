cat vnxlist.txt | while read sn ip model site; 
do 
	echo $sn
	echo naviseccli -h $ip CMD
done
