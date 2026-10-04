#!/bin/sh

PWD=$(pwd)
LOG="/dev/null"
FBINK="/mnt/us/extensions/MRInstaller/bin/K5/fbink -q"
FONT="regular=/usr/java/lib/fonts/Palatino-Regular.ttf"

# PW2
FBROTATE="echo -n 0 > /sys/devices/platform/mxc_epdc_fb/graphics/fb0/rotate"
BACKLIGHT="/sys/devices/system/fl_tps6116x/fl_tps6116x0/fl_intensity"
BATTERY="/sys/devices/system/yoshi_battery/yoshi_battery0/battery_capacity"
TEMP_SENSOR="/sys/devices/virtual/i2c-adapter/i2c-1/1-0068/papyrus_temperature"


clear_screen() {
    $FBINK -f -c
    $FBINK -f -c
}


### Prep Kindle...
echo "`date '+%Y-%m-%d_%H:%M:%S'`: ------------- Startup ------------" >> $LOG

# Kindle must have WiFi connected at startup
if [ `lipc-get-prop com.lab126.wifid cmState` != "CONNECTED" ]; then
    exit 1
fi

$FBINK -w -c -f -m -t $FONT,size=20,top=410,bottom=0,left=0,right=0 \
    "Starting Clock..." > /dev/null 2>&1


### Stop processes that we don't need
stop lab126_gui
stop otaupd
stop phd
stop tmd
stop x
stop todo
stop mcsd

sleep 2


### Turn off 270 degree rotation
eval $FBROTATE


### Lowest CPU clock
echo powersave > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor


### Disable Kindle screensaver
lipc-set-prop com.lab126.powerd preventScreenSaver 1


### Initial time synchronization
ntpdate -s de.pool.ntp.org

clear_screen


while true; do

    echo "`date '+%Y-%m-%d_%H:%M:%S'`: Drawing ambient clock." >> $LOG

    ################################################################
    # AMBIENT CLOCK
    #
    # Black background
    # White time
    # White date
    ################################################################

    clear_screen

    TIME=`date '+%H:%M'`
    DATE=`date '+%A, %-d. %B %Y'`

    # Time
    $FBINK -b -c -m \
        -t $FONT,size=150,top=10,bottom=0,left=0,right=0 \
        "$TIME"

    # Date
    $FBINK -b -m \
        -t $FONT,size=20,top=410,bottom=0,left=0,right=0 \
        "$DATE"

    # Update framebuffer
    $FBINK -w -s


    ################################################################
    # DIM BACKLIGHT
    ################################################################

    echo -n 0 > $BACKLIGHT


    ################################################################
    # WAKE UP AT THE START OF THE NEXT MINUTE
    ################################################################

    NOW=`date +%s`

    WAKEUP_TIME=$(( ((NOW + 59) / 60) * 60 ))
    SLEEP_SECS=$(( WAKEUP_TIME - NOW ))

    # Prevent a sleep interval that is too short
    if [ "$SLEEP_SECS" -lt 5 ]; then
        SLEEP_SECS=$(( SLEEP_SECS + 60 ))
    fi

    echo "`date '+%Y-%m-%d_%H:%M:%S'`: Sleeping for $SLEEP_SECS seconds." >> $LOG


    ################################################################
    # PROGRAM RTC WAKEUP
    ################################################################

    rtcwake -d /dev/rtc1 -m no -s $SLEEP_SECS


    ################################################################
    # SUSPEND TO MEMORY
    ################################################################

    echo mem > /sys/power/state

done
