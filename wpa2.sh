#!/system/bin/sh
INIT_ACCESS_POINT="/system/xbin/initAccessPoint"
INIT_ACCESS_POINT_BACKUP="/system/xbin/initAccessPoint.bak"
DEFAULT_PASSWORD="skycontroller" # such security

ACTION=$1
I_AM=$(whoami)


if [ "$ACTION" = "-h" ]; then
    echo "This script can modify a SkyController 1 to use WPA2 encryption for it's WiFi network"
    echo "It should be run as root"
    echo
    echo "available options:"
    echo "-i - install"
    echo "-u - uninstall"
    echo "-e - enable"
    echo "-d - disable"
    echo "-s - status"
    echo "-p <password> - set WiFi password"
    echo "    the password is not sanitized, just don't choose a weird one"
    echo "-a - apply configuration (restarts ap if needed)"
    echo "-h - print this help text"
    exit 0
else
    if [ "$I_AM" != "root" ]; then
        echo "please run this script as root"
        echo "(type su and hit enter before running it)"
        exit -1
    fi
fi

INSTALLED=0
if [ -f "$INIT_ACCESS_POINT_BACKUP" ]; then
    INSTALLED=1
fi

INSTALL=0

if [ "$ACTION" = "-e" ]; then
    if [ "$INSTALLED" = "1" ]; then
        SCConfig set "WIFI_WPA2_ENABLED" 1
        echo "wpa2 enabled"
        echo "use -a to apply the new configuration (or just switch the SykController off and on again)"
    else
        echo "please install first"
    fi
    exit 0
elif [ "$ACTION" = "-d" ]; then
    if [ "$INSTALLED" = "1" ]; then
        SCConfig set "WIFI_WPA2_ENABLED" 0
        echo "wpa2 disabled"
        echo "use -a to apply the new configuration (or just switch the SykController off and on again)"
    else
        echo "please install first"
    fi
    exit 0
elif [ "$ACTION" = "-s" ]; then
    echo "current status:"
    if [ "$INSTALLED" = "1" ]; then
        echo "installed"
        ENABLED=$(SCConfig get "WIFI_WPA2_ENABLED")
        ENABLED_APPLIED=$(SCConfig get "WIFI_WPA2_ENABLED_APPLIED")
        if [ "$ENABLED" = "1" ]; then
            if [ "$ENABLED_APPLIED" = "1" ]; then
                echo "wpa2 enabled"
            else
                echo "wpa2 set to enabled but config not yet applied"
            fi
        else
            if [ "$ENABLED_APPLIED" = "1" ]; then
                echo "wpa2 set to disabled but config not yet applied"
            else
                echo "wpa2 disabled"
            fi
        fi
    else
        echo "not installed"
    fi
    exit 0
elif [ "$ACTION" = "-p" ]; then
    if [ "$INSTALLED" = "1" ]; then
        PASSWORD=$2
        if [ "$PASSWORD" != "" ]; then
            echo "changing password"
            SCConfig set "WIFI_WPA2_PSK" "$PASSWORD"
            echo "use -a to apply the new configuration (or just switch the SykController off and on again)"
        else
            echo "empty or missing parameter <password>"
        fi
    else
        echo "please install first"
    fi
    exit 0
elif [ "$ACTION" = "-a" ]; then
    echo "applying configuration"
    /system/xbin/initAccessPoint
    exit 0
elif [ "$ACTION" = "-u" ]; then
    if [ -f "$INIT_ACCESS_POINT_BACKUP" ]; then
        echo "uninstalling"
        SCConfig set "WIFI_WPA2_ENABLED" 0
        /system/xbin/initAccessPoint
        # remount /system as rw
        mount -o rw,remount /system
        cp "$INIT_ACCESS_POINT_BACKUP" "$INIT_ACCESS_POINT"
        rm "$INIT_ACCESS_POINT_BACKUP"
        mount -o ro,remount /system
        SCConfig remove "WIFI_WPA2_ENABLED"
        SCConfig remove "WIFI_WPA2_PSK"
        SCConfig remove "WIFI_WPA2_ENABLED_APPLIED"
        SCConfig remove "WIFI_WPA2_PSK_APPLIED"
        echo "done"
    else
        echo "already uninstalled"
    fi
    exit 0
elif [ "$ACTION" = "-i" ]; then
    INSTALL=1
else
    echo "try -h for help"
    exit 0
fi


if [ "$INSTALL" = "0" ]; then
    echo "How did we get here?"
    exit 0
fi

# if this is reached we should install
if [ "$INSTALLED" = "1" ]; then
    echo "already installed"
    exit 0
fi
echo "installing"

# remount /system as rw
mount -o rw,remount /system

# make a backup of the original script
# and use that backup if it already exists

if [ -f "$INIT_ACCESS_POINT_BACKUP" ]; then
    cp "$INIT_ACCESS_POINT_BACKUP" "$INIT_ACCESS_POINT"
else
    cp "$INIT_ACCESS_POINT" "$INIT_ACCESS_POINT_BACKUP"
fi



# modify initAccessPoint
echo "modifying $INIT_ACCESS_POINT"

# it might be possible to make this a little prettier, but this works so meh
sed -i -e '/^COUNTRY=\$(SCConfig get "WIFI_COUNTRY_APPLIED")/a WPA2_ENABLED=$(SCConfig get "WIFI_WPA2_ENABLED")\
PREV_WPA2_ENABLED=$(SCConfig get "WIFI_WPA2_ENABLED_APPLIED")\
WPA2_PSK=$(SCConfig get "WIFI_WPA2_PSK")\
PREV_WPA2_PSK=$(SCConfig get "WIFI_WPA2_PSK_APPLIED")'\
 -e '/^NEED_HOSTAPD=NO/a if [ "$WPA2_ENABLED" != "$PREV_WPA2_ENABLED" ]; then\
	echo "WPA2_ENABLED changed from $PREV_WPA2_ENABLED to $WPA2_ENABLED -> restart hostapd"\
	NEED_HOSTAPD=YES\
elif [ "$WPA2_PSK" != "$PREV_WPA2_PSK" ]; then\
	if [ "$WPA2_ENABLED" = "1" ]; then\
		echo "WPA2_PSK changed from $PREV_WPA2_PSK to $WPA2_PSK and WPA2 is enabled -> restart hostapd"\
		NEED_HOSTAPD=YES\
	else\
		echo "WPA2_PSK changed from $PREV_WPA2_PSK to $WPA2_PSK but WPA2 is disabled"\
	fi\
fi'\
 -e '/^\tSCConfig set WIFI_CHANNEL_APPLIED \$CHANNEL/a \    SCConfig set WIFI_WPA2_ENABLED_APPLIED "\$WPA2_ENABLED"\
    SCConfig set WIFI_WPA2_PSK_APPLIED "\$WPA2_PSK"'\
 -e '/^\tchmod 0644 \/data\/misc\/wifi\/wl18xx_final_hostapd.conf/i \	# Write WPA2 stuff to hostapd.conf if needed\
	if [ $WPA2_ENABLED = "1" ]; then\
		echo "auth_algs=1" >> /data/misc/wifi/wl18xx_final_hostapd.conf\
		echo "wpa=2" >> /data/misc/wifi/wl18xx_final_hostapd.conf\
		echo "wpa_passphrase=$WPA2_PSK" >> /data/misc/wifi/wl18xx_final_hostapd.conf\
		echo "wpa_key_mgmt=WPA-PSK" >> /data/misc/wifi/wl18xx_final_hostapd.conf\
		echo "rsn_pairwise=CCMP" >> /data/misc/wifi/wl18xx_final_hostapd.conf\
	fi'\
 "$INIT_ACCESS_POINT"

mount -o ro,remount /system

# set SCConfig variables
SCConfig set "WIFI_WPA2_ENABLED" 0
SCConfig set "WIFI_WPA2_PSK" "$DEFAULT_PASSWORD"
SCConfig set "WIFI_WPA2_ENABLED_APPLIED" 0
SCConfig set "WIFI_WPA2_PSK_APPLIED" ""


echo "done"
echo
echo "password set to default :\"$DEFAULT_PASSWORD\""
echo "use -p <password> to set another password"
echo "use -e to enable wpa2"
echo "use -a to apply your new configuration"
echo "use -h to see what else this script can do"
