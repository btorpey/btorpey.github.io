#!/bin/bash

# cribbed from http://unix.stackexchange.com/questions/33450/checking-if-hyperthreading-is-enabled-or-not
#
# NOTE:  There does not seem to be a good way to determine if HT is available but not enabled on a particular machine:
# - 'ht' flag in /proc/cpuinfo is unreliable
# - lscpu could be used, but is not part of RH5
# - dmidecode could be used, but requires root permissions
#
# So for now we just report whether HT is enabled or not

echo -n ${HOSTNAME}

nproc=$(grep -i "processor" /proc/cpuinfo | sort -u | wc -l)
phycore=$(cat /proc/cpuinfo | egrep "core id|physical id" | tr -d "\n" | sed s/physical/\\nphysical/g | grep -v ^$ | sort -u | wc -l)
if [ -z "$(echo "$phycore *2" | bc | grep $nproc)" ]; then
   echo ": HT disabled"
else
   echo ": HT enabled"
fi
