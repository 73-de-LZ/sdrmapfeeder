#!/bin/bash
export LANG=C.UTF-8
source /etc/default/sdrmapfeeder

version='4.LZ.a'
sysinfolastrun=0
radiosondelastrun=0


if [[ -z $username ]] || [[ -z $password ]] || [[ $username == "yourusername" ]] || [[ $password == "yourpassword" ]]; then
	echo "Please edit your credentials."
	exit 1
fi

if [ "$radiosonde" = "true" ]; then
	if [ ! -d "$radiosondepath" ]; then
		echo "The log directory '$radiosondepath' doesn't exist."
		exit 1
	fi
fi

while true; do
	if [ "$sysinfo" = "true" ] && [ $(($(date +"%s") - $sysinfolastrun)) -ge "$sysinfointerval" ]
		then
		sysinfolastrun=$(date +"%s")
echo "{\
	\"cpu\":{\
		\"model\":\"$(cat /proc/cpuinfo |grep 'model name'|tail -n 1|cut -d ':' -f 2)\",\
		\"cores\":\"$(cat /proc/cpuinfo |grep -c -e '^processor')\",\
		\"load\":\"$(cat /proc/loadavg |cut -d ' ' -f 1)\",\
		\"temp\":\"$(($(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null |sort -n|tail -n 1)/1000))\"\
	},\
		\"memory\":{\
			\"total\":\"$(cat /proc/meminfo |grep 'MemTotal:'|cut -d ':' -f 2|awk '{$1=$1};1')\",\
			\"free\":\"$(cat /proc/meminfo |grep 'MemFree:'|cut -d ':' -f 2|awk '{$1=$1};1')\",\
			\"available\":\"$(cat /proc/meminfo |grep 'MemAvailable:'|cut -d ':' -f 2|awk '{$1=$1};1')\"\
		},\
		\"uptime\":\"$(cat /proc/uptime |cut -d ' ' -f 1)\",\
		\"os\":{\
			\"kernel\":\"$(uname -r)\"\
		},\
		\"feeder\":{\
			\"version\":\"$version\",\
			\"interval\":\"$sysinfointerval\"
		}\
	}"| gzip -c |curl -s -u $username:$password -X POST -H "Content-type: application/json" -H "Content-encoding: gzip" --data-binary @- https://sys.feed.sdrmap.org/index.php
	fi;

	# if [ "$adsb" = "true" ]
	# then
	# 	gzip -c $adsbpath | curl -s -u $username:$password -X POST -H "Content-type: application/json" -H "Content-encoding: gzip" --data-binary @- https://adsb.feed.sdrmap.org/index.php
	# fi;
	if [ "$adsb" = "true" ]
	then
    	curl -s $adsbpath | gzip -c | curl -s -u $username:$password -X POST -H "Content-type: application/json" -H "Content-encoding: gzip" --data-binary @- https://adsb.feed.sdrmap.org/index.php
	fi;

	if [ "$radiosonde" = "true" ] && [ $(($(date +"%s") - $radiosondelastrun)) -ge "$radiosondeinterval" ]
		then
		radiosondelastrun=$(date +"%s")
		for i in $(find $radiosondepath -mmin -0.5 -name "*sonde.log");
			do
			tail -n 1 $i | gzip | curl -s -u $username:$password -X POST -H "Content-type: application/json" -H "Content-encoding: gzip" --data-binary @- https://radiosonde.feed.sdrmap.org/index.php
		done;
	fi;

	sleep 1;
done;

