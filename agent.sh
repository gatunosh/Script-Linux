#!/bin/bash

echo "Installing"
echo "==========================================================="

apt-get install jq
apt-get net-tools
apt-get install network-manager

echo "==========================================================="
echo "Starting the script"
echo "==========================================================="

json="assets_values.json"

lshw -json > $json

echo -e '{' > assets.json


PCModel=$(jq -r '.[] .product' $json)
echo "\"PCModel\": \"$PCModel\"," >> assets.json

PCManufacturer=$(jq -r '.[] .vendor' $json)
echo "\"PCManufacturer\": \"$PCManufacturer\"," >> assets.json

Hostname=$(jq -r '.[] .id' $json)
echo "\"Hostname\": \"$Hostname\"," >> assets.json

ChassisType=$(jq -r '.[] .configuration .chassis' $json)
echo "\"ChassisType\": \"$ChassisType\"," >> assets.json

WirelessAdapter=$(jq -r '.[] .children[0] .children[3] .children[8] .children[0] .product' $json)
echo "\"WirelessAdapter\": \"$WirelessAdapter\"," >> assets.json

WirelessMAC=$(jq -r '.[] .children[0] .children[3] .children[8] .children[0] .serial' $json)
echo "\"WirelessMAC\": \"$WirelessMAC\"," >> assets.json

WiredAdapter=$(jq -r '.[] .children[0] .children[3] .children[9] .children[0] .product' $json)
echo "\"WiredAdapter\": \"$WiredAdapter\"," >> assets.json

WiredMAC=$(jq -r '.[] .children[0] .children[3] .children[9] .children[0] .serial' $json)
echo "\"WiredMAC\": \"$WiredMAC\"," >> assets.json

video_controller_vendor=$(jq -r '.[] .children[0] .children[3] .children[0] .vendor' $json)
video_controller_product=$(jq -r '.[] .children[0] .children[3] .children[0] .product' $json)
VideoController="$video_controller_vendor $video_controller_product"
echo "\"VideoController\": \"$VideoController\"," >> assets.json

audio_controller_vendor=$(jq -r '.[] .children[0] .children[3] .children[12] .vendor' $json)
audio_controller_name=$(jq -r '.[] .children[0] .children[3] .children[12] .product' $json)
echo "\"AudioController\": [{\"Manufacturer\": \"$audio_controller_vendor\",\"Name\": \"$audio_controller_name\",\"Status\": null,\"StatusInfo\": null}]," >> assets.json

# Tha ram may be separated so We've gotta iterate the slots to get the information
readarray -t slots < <(jq -c '.[] .children[0] .children[2] .children[]' $json)
slots_len=${#slots[@]}
COUNTER=0
echo "\"RAM\": [" >> assets.json
for item in "${slots[@]}";do
        echo -e '{' >> assets.json

        RAMManufacturer=$(jq '.vendor' <<< "$item")
        echo "\"Manufacturer\": $RAMManufacturer," >> assets.json

        RAMConfiguredclockspeed=$(jq '.clock' <<< "$item")
        echo "\"Configuredclockspeed\": $RAMConfiguredclockspeed," >> assets.json

        RAMDevicelocator=$(jq '.slot' <<< "$item")
        echo "\"Devicelocator\": $RAMDevicelocator," >> assets.json

        RAMSerialnumber=$(jq '.serial' <<< "$item")
        echo "\"Serialnumber\": $RAMSerialnumber," >> assets.json

        # Convert from bytes to GB
        ram_capacity_size=$(jq '.size' <<< "$item")
        ram_size_gb=$((ram_capacity_size / 1000000000))
        RAMCapacityGB=${ram_size_gb/\.*/}
        echo "\"CapacityGB\": $RAMCapacityGB" >> assets.json

        let COUNTER++
        if [ "$COUNTER" -eq "$slots_len" ] 
        then
                echo '}' >> assets.json
        else
                echo '},' >> assets.json
        fi
done
echo '],' >> assets.json

Processor=$(jq -r '.[] .children[0] .children[1] .product' $json)
echo "\"Processor\": \"$Processor\"," >> assets.json

BiosVersion=$(jq -r '.[] .children[0] .children[0] .version' $json)
echo "\"BiosVersion\": \"$BiosVersion\"," >> assets.json

BIOSVendor=$(jq -r '.[] .children[0] .children[0] .vendor' $json)
echo "\"BIOSVendor\": \"$BIOSVendor\"," >> assets.json

OS=$(jq -r '.[] .children[0] .children[13] .children[0] .children[0] .vendor' $json)
echo "\"OS\": \"$OS\"," >> assets.json

OSVersion=$(jq -r '.[] .children[0] .children[13] .children[0] .children[0] .version' $json)
echo "\"OSVersion\": \"$OSVersion\"," >> assets.json

rm $json

# Wifi Access Points
declare nmcli_awifi=( $(nmcli -f BSSID,CHAN dev wifi) )
nmcli_awifi=("${nmcli_awifi[@]:2}")
nmcli_len=$((${#nmcli_awifi[@]}-1))
echo "\"wifiAccessPoints\": [" >> assets.json
for i in "${!nmcli_awifi[@]}";do
        if [ $(($i%2)) -eq 0 ]
        then
                echo -e '{' >> assets.json
                chanel=$((i + 1))
                echo "\"macAddress\": \"${nmcli_awifi[$i]}\"," >> assets.json
                echo "\"chanel\": \"${nmcli_awifi[$chanel]}\"" >> assets.json
                if [ "$chanel" -eq "$nmcli_len" ] 
                then
                        echo '}' >> assets.json
                else
                        echo '},' >> assets.json
                fi
        fi
done

echo '],' >> assets.json

# IPs
declare ip_address=( $(ifconfig -a|awk '{print $1 ":" $2 " " $3 ":" $4}'|egrep -w 'Link|inet'|sed 's/ Link//'|sed 's/inet addr://') )
ip_address=("${ip_address[@]:2}")
echo "\"PrivateIP\": \"${ip_address[0]}\"," >> assets.json
echo "\"SubnetMask\": \"${ip_address[1]}\"," >> assets.json

declare gateway=( $(ip r | grep default) )
gateway=("${gateway[@]:2}")
echo "\"DefaultGateway\": \"${gateway[0]}\"," >> assets.json

PublicIP=$(curl ifconfig.me)
echo "\"PublicIP\": \"$PublicIP\"," >> assets.json

#DNS
declare dns=( $(grep nameserver /etc/resolv.conf -a|awk '{print $2}') )
echo "\"DNS\": [" >> assets.json
dns_len=$((${#dns[@]}-1))
for i in "${!dns[@]}";do
        if [ "$i" -eq "$dns_len" ] 
        then
                echo "\"${dns[$i]}\"" >> assets.json
        else
                echo "\"${dns[$i]}\"," >> assets.json
        fi
done
echo "]," >> assets.json

#Software
declare software=( $(apt show '~i' -a|awk '{print $1" "$2}'|egrep -wv 'Original-Maintainer|Dpkg::Source::Package|Dpkg::Version:|Description|X Version'|egrep -w 'Package|Maintainer|Version'|sed 's/Package: //'|sed 's/Maintainer: //'|sed 's/Version: //') )
software_len=$((${#software[@]}-1))
echo "\"Software\": [" >> assets.json
for i in "${!software[@]}";do
        if [ $(($i%3)) -eq 0 ]
        then
                # $i is the software name. As the command executed before take the data in the next order:
                # Software name -> Package
                # Version -> Version
                # Publisher -> Maitainer
                echo -e '{' >> assets.json
                version=$((i + 1))
                publisher=$((i + 2))
                echo "\"DisplayName\": \"${software[$i]}\"," >> assets.json
                echo "\"Version\": \"${software[$version]}\"," >> assets.json
                echo "\"InstallDate\": null," >> assets.json
                echo "\"Publisher\": \"${software[$publisher]}\"" >> assets.json
                if [ "$i" -eq "$software_len" ] 
                then
                        echo '}' >> assets.json
                else
                        echo '},' >> assets.json
                fi
        fi
done
echo "]," >> assets.json
echo "\"SystemDirectory\": \"/boot\"," >> assets.json

declare LastUser=( $(last -n 1 -w -R --time-format iso -a|awk '{print $1  " " $3 " " $5}'|egrep -wv 'wtmp') )
echo "\"LastLoggedOnUser\": {" >> assets.json

echo "\"User\": \"${LastUser[0]}\"," >> assets.json
echo "\"Time\": \"${LastUser[1]}\"," >> assets.json

if [ "${LastUser[2]}" == "logged" ] 
then
        echo "\"CurrentlyLoggedOn\": true," >> assets.json
else
        echo "\"CurrentlyLoggedOn\": false," >> assets.json
fi

echo "\"Computer\": \"$Hostname\"" >> assets.json

echo '},' >> assets.json

# HD INFO
echo "\"HDInfo\": {" >> assets.json

HDModel=( $(hdparm -I /dev/sda|egrep 'Model Number' -a|awk '{print $(NF)}') )
echo "\"Model\": \"$HDModel\"," >> assets.json

HDSerial=( $(hdparm -I /dev/sda|egrep 'Serial Number' -a|awk '{print $(NF)}') )
echo "\"Serial\": \"$HDSerial\"," >> assets.json

HDMode=( $(lshw -c disk|egrep 'partitioned:' -a|awk '{print $2}') )
echo "\"Mode\": \"$HDMode\"," >> assets.json

HDPath=( $(lshw -c disk|egrep 'logical name: ' -a|awk '{print $(NF)}') )
echo "\"Path\": \"$HDPath\"," >> assets.json

HDFreeBytes=( $(hdparm -I /dev/sda|egrep 'device size with M = 1024' -a|awk '{print $7}') )
HDFreeGB=$(($HDFreeBytes / 1024))
FreeGB=${HDFreeGB/\.*/}
echo "\"FreeGB\": $FreeGB," >> assets.json

HDBusInfo=( $(lshw -c disk|egrep 'bus info:' -a|awk '{print $(NF)}') )
echo "\"BUS\": \"$HDBusInfo\"," >> assets.json

HDFirmware=( $(hdparm -I /dev/sda|egrep 'Firmware Revision' -a|awk '{print $(NF)}') )
echo "\"Firmware\": \"$HDFirmware\"" >> assets.json

echo '},' >> assets.json

echo "\"GeoLocation\": {" >> assets.json


GeoLocation=( $(curl ipinfo.io/loc) )
ArrayGeoLocation=(${GeoLocation//;/})
Latitude=( $(echo "$ArrayGeoLocation" | cut -d "," -f 1) )
echo "\"Latitude\": \"$Latitude\"," >> assets.json
Longitude=( $(echo "$ArrayGeoLocation" | cut -d "," -f 2) )
echo "\"Longitude\": \"$Longitude\"" >> assets.json

echo '},' >> assets.json

TimeZone=( $(cat /etc/timezone) )

echo "\"TimeZone\": \"$TimeZone\"," >> assets.json

# Users Profile 

declare UserProfiles=( $(getent passwd {1000..6000} | cut -d ":" -f 1) )
declare UserProfilesLoggedIn=( $(who -u |awk '{print $1 ":" $3}') )
user_profiles_len=$((${#UserProfiles[@]}-1))
echo "\"UserProfiles\": [" >> assets.json
for i in "${!UserProfiles[@]}"; do

echo -e '{' >> assets.json
echo "\"UserName\": \"${UserProfiles[$i]}\"," >> assets.json
FLAG=0
for j in "${!UserProfilesLoggedIn[@]}"; do
        
        USERNAME=( $(echo "${UserProfilesLoggedIn[$j]}" | cut -d ":" -f 1) )
        DATE=( $(echo "${UserProfilesLoggedIn[$j]}" | cut -d ":" -f 2) )
        if [ "${UserProfiles[$i]}" == "$USERNAME" ] 
        then
                echo "\"Loaded\": true," >> assets.json
                echo "\"LastUseTime\": \"$DATE\"" >> assets.json
                let FLAG=1
        fi

done

if [ "$FLAG" == 0 ] 
then
        echo "\"Loaded\": false," >> assets.json
        echo "\"LastUseTime\": null" >> assets.json
fi

if [ "$i" -eq "$user_profiles_len" ] 
then
        echo '}' >> assets.json
else
        echo '},' >> assets.json
fi

done

echo "]," >> assets.json

echo "\"WipeCapabilities\": []," >> assets.json
echo "\"BitLockerStatus\": null," >> assets.json
echo "\"Monitor\": null," >> assets.json
echo "\"Description\": null," >> assets.json
echo "\"WOL\": false," >> assets.json
echo "\"Virtual\": false," >> assets.json
echo "\"SCCMClient\": null," >> assets.json
echo "\"SCCMMP\": null" >> assets.json

echo '}' >> assets.json























