#!/bin/bash

echo "Installing"
echo "==========================================================="

#sudo apt-get install jq

echo "==========================================================="
echo "Starting the script"
echo "==========================================================="

json="assets_values.json"

sudo lshw -json > $json

echo -e '{' > assets.json

# LAST TIME -> $(echo "$json" | jq -r '.[] .product')

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

echo '}' >> assets.json






