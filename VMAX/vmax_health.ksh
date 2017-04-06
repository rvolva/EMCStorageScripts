#!/bin/ksh

export PATH=$PATH:/opt/emc/SYMCLI/bin

CALVMAXLIST="0718 3512 4615 2276 2278 1145"
COVVMAXLIST="1139"

export SYMCLI_CONNECT=SMIPRDCGY001

for sid in $CALVMAXLIST; do
	echo "--$sid faults---------------"
	symcfg -sid $sid list -env_data  -v | egrep "Bay Name|Failed"
	symdisk -sid $sid list -failed
	echo
done

export SYMCLI_CONNECT=SMIPRDTOR001

for sid in $COVVMAXLIST; do
	echo "--$sid faults---------------"
	symcfg -sid $sid list -env_data -v | egrep "Bay Name|Failed"
	symdisk -sid $sid list -failed
	echo 
done
