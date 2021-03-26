#!/bin/sh
#************************************************
#function: collect the memory info of the system
#author:   Guanjun He(heguanbo@gmail.com)
#date:     Jun 18,2009

#enhanced by: Guanjun He
#************************************************

mem_overview() 
{
	echo "Memory OverView:"
	sort +1nr /proc/meminfo
}

mem_avail()
{
	#need the second port module(mem.ko) loaded
	slabfree=$(cat /proc/slabinfo |awk '{i++;if(i>2)print $0}'|awk '{total+=($3-$2)*$4} END{print total}')
	cat /proc/mem|awk -vslab_free=$slabfree '{
	i++;if(i==1)printf("%s %10s %20s\n",$0,"slab_free","total_avail(Bytes)");
	if(i==2)printf("%s %10s %20s\n",$0, slab_free, ($10)*4096+slab_free)}'
}

mem_summary()
{
	#not accurate, maybe some caches or buffers are locked,or ...
	free
}

mem_cache()
{
	sed -n 2p /proc/slabinfo
	sed 1,2d /proc/slabinfo|sort +2nr 
}

#Memory used by each process
mem_all_process()
{
	rm_filelist="/tmp/foundfiles"
	rm -rf $rm_filelist 2>/dev/null

	echo `find /proc -maxdepth 2 -name "statm" 2>/dev/null` 2>/dev/null  > /tmp/foundfiles

	declare -a arr_filename
	arr_filename=($(cat /tmp/foundfiles))
	num=${#arr_filename[@]}

	declare -a arr_result

	num2=0;
	for ((i=0;i<$num;i++))
	do
		if [ -r ${arr_filename[$i]} ];then
			#pid
			tmp1=$(echo ${arr_filename[$i]} | awk -F/ '{print $3}')
			if [ $tmp1 == $$ ];then
				continue
			fi
			arr_result[$num2]=$tmp1

			#mem info
			arr_result[$((num2+1))]=$(awk '{t1 += $2;t2+=$3;} END { print t1" "t2;}' ${arr_filename[$i]}) 

			#process file:
			arr_result[$((num2+2))]=$(sed -n 1p /proc/$tmp1/status | awk '{print $2;}')

			num2=$((num2+3))
		fi
	done

	awk 'BEGIN{printf("%5s %10s %10s %s\n\n","PID","RSS(KB)","SHR(KB)","COMMAND")}'
	for((i=0;i<$num2;i+=3))
	do
		echo ${arr_result[$i]}  ${arr_result[$((i+1))]} ${arr_result[$((i+2))]}
	done |sort +1nr|awk '{printf("%5s %10s %10s %s\n",$1,$2*4,$3*4,$4)}'

	#delete any file created in this function
	rm -rf $rm_filelist 2>/dev/null
}

mem_one_process()
{
	ret=$(awk -vpid_tmp=$1 'BEGIN{if(pid_tmp ~ /^[0-9]*$/) print 1;else print 0}')
	if [ $ret -eq 0 ];
	then
		echo "wrong pid: $1"
		return 1
	fi

	process_tmp="/proc/$1/statm"
	if [ -r "$process_tmp" ];then
		mem_tmp=$(awk '{print $2" "$3;}' $process_tmp)
		file_tmp=$(sed -n 1p /proc/$1/status 2>/dev/null | awk '{print $2;}')
		echo $1 $mem_tmp $file_tmp|awk '{printf("%5s %10s %10s %s\n",$1,$2*4,$3*4,$4)}'
	fi
}

#Every User used private memory accounting
mem_all_user()
{
	awk 'BEGIN{printf("%5s %20s %20s\n\n","UID","USERNAME","RSS_TOTAL(SIZE/KB)")}'

	tmplineofpasswd=`cat /etc/passwd|wc -l`
	for ((k=1;k<=$tmplineofpasswd;k++))
	do
		tmp_uid=$(sed -n ${k}p /etc/passwd|awk -F: '{print $1" "$3}')
		mem_one_user $tmp_uid
	done
}

mem_one_user()
{
	#$1 is username
	user_id=$(cat /etc/passwd|awk -vu_name=$1 -F: '{if($1==u_name){print $3}}')

	cat `find /proc -maxdepth 2 -name "status" 2>/dev/null` 2>/dev/null |
	awk '{
	if ($1=="Pid:")
		i=$2;
		if ($1=="Uid:")
			#connect all the pids of one uid
			relation[$2] = relation[$2]" "i;
		} END {
		for (i in relation) {
			print i relation[i]>>"relation.txt";
		}
	}'

	filelines=`cat relation.txt|wc -l`
	for ((i=1;i<=$filelines;i++))
	do
		userid=$(sed -n ${i}p relation.txt|awk '{print $1}')
		if [ $userid == $user_id ];then
		{
			tmp_line=$(sed -n ${i}p relation.txt)
			declare -a p_id
			p_id=($tmp_line)
			for ((j=1;j<${#p_id[@]};j++))
			do
				#add the mem of the processes for this user,exclude itself
				if [ ${p_id[$j]} == $$ ];then
					continue
				fi
				tmp=$(mem_one_process ${p_id[$j]}|awk '{print $2}')
				memoryused=$((memoryused+tmp))
			done
			echo $userid $1 $memoryused|awk '{printf("%5s%20s%20s\n",$1,$2,$3)}'
			break
		}
		fi
	done

	#delete any file created in this function
	rm -rf relation.txt 2>/dev/null
}

mem_sysvipc_shm()
{
	if [ -r /proc/sysvipc/shm ]
	then
		cat /proc/sysvipc/shm
	fi
}

mem_version()
{
	cat <<-END
	Version: 0.01, gjhe@novell.com
END
}

mem_usage()
{

	cat <<END

	Usage:

	-a	accurate avail memory of the system in real time(need the second part kernel module's support)

	-o	overview of the system mem,include more info than -s

	-s	summary of the system's memory info

	-c	whole system cache info

	-P	all processes memory info

	-p	one process memory info,need an option-argument pid,
		for example: $0 -p 12345

	-U	all(each) users memory info

	-u	one user memory info,need an option-argument username
		for example: $0 -u root

	-V	version info

	-v	sysvipc shared memory info

END
}


if [ -z $1 ]
then
{
	mem_usage
	exit
}
else
{
	first_char=$(echo "$1"|cut -b 1)
	if [ $first_char != "-" ];then
		mem_usage
		exit
	fi
}
fi

while getopts "oscPp:Uu:Vva" Option
do
	case $Option in
		a)	mem_avail
		;;
		o)	mem_overview
		;;
		s)	mem_summary
		;;
		c)	mem_cache
		;;
		p)	
			awk 'BEGIN{printf("%5s %10s %10s %s\n","PID","RSS(KB)","SHR(KB)","COMMAND")}'
			mem_one_process $OPTARG
		;;
		P)	mem_all_process
		;;
		u)	
			awk 'BEGIN{printf("%5s %20s %20s\n\n","UID","USERNAME","RSS_TOTAL(SIZE/KB)")}'
			mem_one_user $OPTARG
		;;
		U)	mem_all_user
		;;
		V)	mem_version
		;;
		v)	mem_sysvipc_shm
		;;
		*)	mem_usage
		;;
	esac
done

shift $((OPTIND-1))

