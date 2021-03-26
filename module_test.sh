#!/bin/sh

total=0;
loopnum=0;
for((i=0;i<1000;i++))
do
	insmod mem.ko
	cat /proc/mem
	if [ $? -eq 0 ]
	then
		total=$((total+1))
		if [ $((total/1000)) -gt $loopnum ]
		then
			loopnum=$((loopnum+1))
			#if [ $loopnum -gt 20 ] 
			#then
				#sleep 20
			#else
				#sleep $((5+loopnum))
			#fi
		fi
		echo $total
		#sleep 1
	else
		echo "cat /proc/mem failed"
		break
		
	fi
	rmmod mem.ko
done
exit
