# Parrot SkyController 1 WPA2
Allows you to set a WiFi password for the Parrot SkyController 1.  


## Install:
All you need is a computer with adb and a usb to micro usb cable.
- Turn on your SkyController, without the micro usb cable plugged in, and wait a little.  
  (Or it will start in flashing mode.)
- Plug the usb cable into your computer and the SkyController.
- Open a terminal in this project's root and run:
  ```bash
      adb usb
  ```
- The SkyController should now be listed by:
  ```bash
      adb devices
  ```
- Then push the script to the SkyController with:
  ```bash
      adb push wpa2.sh /data/local/tmp/wpa2.sh
  ```
- And run these commands, one after the other:
  ```bash
      adb shell
      su
      mount -o rw,remount /system
      cp /data/local/tmp/wpa2.sh /system/xbin/wpa2
      rm /data/local/tmp/wpa2.sh
      chmod 755 /system/xbin/wpa2
      mount -o ro,remount /system
      exit
      exit
  ```


## Usage:
The script should always be run as root (if you don't do that it will complain).  
So before you call it run:
```bash
    adb shell
    su
```
From there you can call it as:
```bash
    wpa2
```

### Arguments:
(call is with -h to also print this list)
- -i - install
- -u - uninstall
- -e - enable
- -d - disable
- -s - status
- -p <password> - set WiFi password  
   the password is not sanitized, just don't choose a weird one
- -a - apply configuration (restarts ap if needed)
- -h - print this help text


## Completely remove:
Run in a terminal:
```bash
    adb shell
    su
    wpa2 -u
    rm /system/xbin/wpa2
    exit
    exit
```
and the script will attempt to undo everything it changed, after which it will delete itself.
