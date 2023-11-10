#!/bin/bash
docker run -it --privileged -v /dev/bus/usb:/dev/bus/usb --net=host --env="DISPLAY" --volume="$HOME/.Xauthority:/home/android/.Xauthority:rw" gnuradio-android
