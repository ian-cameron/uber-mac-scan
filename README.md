# Uberscan
MAC address capture from three sources. (Bash script) 
Records and save MAC address, Timestamp, and RSSI levels.

* Bluetooth Classic
* Bluetooth Smart (Bluetooth Low Energy)
* Wifi

### Software Requirements:

TCPdump
bluez
bluez-hcidump
iwconfig


### Hardware Requirements

SoftMAC USB WiFi adapter such as Alpha Networks AWUS036H (RTL 8187)
Blueooth 4.0 (or higher) LE or Dual Mode Bluetooth adapter such as Azio BTD-V400
Bluetooth Classic (or >=4.0 Dual Mode) Bluetooth adapter such as Aircable HostXR

### How to run

chmod +x uberscan.sh
sh uberscan.sh
