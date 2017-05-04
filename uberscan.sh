#!/bin/bash
#***********************************************************************************#
#@Name: Triple Capture                                                              #
#@Desc: WiFi Probe, Bluetooth Classic Inqury & Bluetooth Low Energy Advertisement   #
#       MAC Address Capture                                                         #
#@Date: 11/16/2013                                                                  #
#@Author: Ian Cameron (ian@digiwest.com)                                            #
#***********************************************************************************#
trap "sum" INT EXIT SIGINT

#colors
red="$(tput setaf 1)"
green="$(tput setaf 2)"
brown="$(tput setaf 3)"
blue="$(tput setaf 4)"
NC="$(tput sgr0)"

#determine monitor mode interface
int=$(iwconfig 2> /dev/null | grep "IEEE 802" | awk '{print $1}')

#Figure out which HCI is version 4.0 (LE)
lehci=0
chci=0
aa=0
while [ "$aa" -lt "3" ]
do
   hciconfig hci$aa down 2> /dev/null
   hciconfig hci$aa up 2> /dev/null
   bb=$(hciconfig hci$aa version 2> /dev/null | grep -c 4.0)
   cc=$(hciconfig hci$aa version 2> /dev/null | grep -c 2.0)
   dd=$(hciconfig hci$aa version 2> /dev/null | grep -c 3.0)
   ee=$(hciconfig hci$aa version 2> /dev/null | grep -c 2.1)
   if [ "$bb" -gt 0 ]
   then
      lehci=$((aa))
   elif [ "$cc" -gt "0" ]
   then
      chci=$((aa))
   elif [ "$dd" -gt "0" ]
   then
      chci=$((aa))
   elif [ "$ee" -gt "0" ]
   then
      chci=$((aa))	
   fi
   aa=$((aa+1))
done

#summary file
summary=$HOME/MACstats

#logfile name
out=output

#logfile name suffix
suf=$(date +"%F_%H_%M_%S")

#seconds of dwell time between WiFi channel hopping
dwell=5

#WiFi channel hopping map
chan=(1 2 3 4 5 6 7 8 9 10 11 12)

#WiFi chanel hopping function
hop()
{
   i=0
   len=${#chan[@]}
   sleep 1
   while [ 1 ]
   do
      c=${chan[i]}
      echo -e "\t\t\t\t\t\t${red}WiFi:${brown} listening on channel $c"
      iwconfig $int 'channel' $c
      i=$(((i+1)%len))
      sleep $dwell
   done
}

wifi()
{
ifconfig $int down > /dev/null
#echo -e "\n${red}WiFi: ${brown}Channel hopping frequency $dwell seconds"
#echo -e "${red}WiFi: ${brown}Channel Map ${chan[*]}${NC}"
echo -e "\n${red}WiFi: ${brown}Setting monitor mode and bringing up interface $int."
echo -e "${red}WiFi: ${brown}Saving results to WF$out$suf.\n"
iwconfig $int mode monitor
ifconfig $int up
sleep 2
hop& P=$!
tcpdump -l -ttt -i $int -et -j host type mgt subtype probe-req 2> /dev/null | \
sed -n 's/^\([0-9-]*\) \([0-9:]*....\).*-\([0-9]\+\)dB.*SA:..:..:..:\(..\):\(..\):\(..\).*Probe Request (\(.*\)).*$/'"${red}"'\1 \2\t\t\4\5\6\t-\3dB'"${brown}\t"'\7/p''w 'WF$out$suf
}

bluetooth()
{
i="$chci"
hciconfig hci$i down 2> /dev/null
hciconfig hci$i up 2> /dev/null
echo -e "${blue}Bluetooth Classic: ${brown}Starting periodic inquiry mode on hci$i."
hcitool -i hci$i cmd 01 0003 30 00 2E 00 33 8b 9e 2D 00 > /dev/null
echo -e "${blue}Bluetooth Classic: ${brown}Saving results to BT$out$suf.\n"
sleep 2
hcidump -i hci$i -t | sed -n 'N;s_\([0-9: /-]*.[0-9][0-9][0-9]\).*\(bdaddr ..:..:\)\(..\):\(..\):\(..\):\(..\).*rssi.*\(\-[0-9][0-9]\)_'"${blue}"'\1\t\t\4\5\6\t\7dB_p''w '$HOME'/'BT$out$suf&
}

le()
{
echo -e "${green}Bluetooth Low Energy: ${brown}Initiating LE scan on hci$lehci."
echo -e "${green}Bluetooth Low Energy: ${brown}Saving results to LE$out$suf."
hciconfig hci$lehci up 2> /dev/null
stdbuf -o 0 hcitool -i hci$lehci lescan | ts "${green}%Y-%m-%d %H:%M:%S.000%t%t" | tee LE$out$suf
}

sum()
{
   echo -e "${NC}"
   kill $P 2> /dev/null
   kill $Q 2> /dev/null
   kill $S 2> /dev/null
   kill 0 2> /dev/null
   hcitool -i hci$chci epinq
   end=$(date +"%s")
   IFS=":" read hh mm < <(date +%:z)
   endtz=$(expr $hh \* 3600 + $mm \* 60)
   dif=$(($end-$beg))
   echo -e "Script started running on $(date -u -d @"$((beg+begtz))" +'%D at %r')."|tee -a $summary
   echo -e "Script ended by user on $(date -u -d @"$((end+endtz))" +'%D at %r')."|tee -a $summary 
   echo -e "${NC}Capture ran for ${brown}$((dif/86400)) days $(date -u -d @"$dif" +'%H hours %M minutes %S seconds')${NC}."| tee -a $summary
   echo -e "\n\n"
   echo -e "${red}WiFi Results:\n-------------${NC}"|tee -a $summary
   uni=$((awk '{print $3}'|sort|uniq|wc -l)<WF$out$suf)
   sid=$((awk '$5 {$1=$2=$3=$4="";print $0}'|sort|uniq|wc -l)<WF$out$suf)
   fff=$(cat WF$out$suf | awk '!$5 {c++} END {print c}')
   if [ -z "$fff" ]; then fff=0; fi
   tot=$( wc -l <WF$out$suf)
   echo $tot WiFi Hits | tee -a $summary
   echo "$fff broadcast probes" | tee -a $summary
   echo "$((tot-fff)) directed probes (to $sid unique SSIDs)"|tee -a $summary
   echo $uni unique MACs| tee -a $summary
   echo ''
   echo -e "${blue}Bluetooth Classic Results:\n--------------------------${NC}"|tee -a $summary
   tot=$( wc -l <BT$out$suf)
   uni=$((awk '{print $3}'|sort|uniq|wc -l)<BT$out$suf)
   echo $tot Bluetooth Classic Hits|tee -a $summary
   echo $uni unique MACs| tee -a $summary
   echo ''
   echo -e "${green}Bluetooth 4.0 LE Results:\n-------------------------${NC}"|tee -a $summary
   tot=$( wc -l <LE$out$suf)
   uni=$((awk '{print $3}'|sort|uniq|wc -l)<LE$out$suf)
   echo $((tot-1)) Bluetooth 4.0 Low Energy Hits| tee -a $summary
   echo $((uni-1)) unique MACs| tee -a $summary
   echo ''|tee -a $summary
}
clear
echo ${brown}
echo -e "\t\t\t=================================="
echo -e "\t\t\tx${NC}  ${red} Triple MAC Address Capture${brown}   x"
echo -e "\t\t\t  x     ${green}     2015     ${brown}         x"
echo -e "\t\t\tx       ${blue} Digiwest, LLC${brown}           x"
echo -e "\t\t\t==================================${NC}\n"

echo -e "Type Ctrl-C to stop...\n"
beg=$(date +"%s")
IFS=":" read hh mm < <(date +%:z)
begtz=$(expr $hh \* 3600 + $mm \* 60)
le& Q=$!
sleep 1
wifi& R=$!
sleep 1
bluetooth& S=$!
sleep 1
echo -e "${NC}Date\t   Time\t\t\tMAC\tRSSI\tSSID"
echo -e "${NC}----\t   ----\t\t\t---\t----\t----"
while [ 1 ]
do
sleep 1
done

