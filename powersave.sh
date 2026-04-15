#!/bin/bash
echo '1' > '/sys/module/snd_hda_intel/parameters/power_save';
#echo 'auto' > '/sys/bus/usb/devices/1-8/power/control'; # Makes USB ports go sleep after 3 seconds of idling.
echo 'auto' > '/sys/bus/usb/devices/1-6/power/control';
echo 'auto' > '/sys/bus/pci/devices/0000:00:0a.0/power/control';
echo 'auto' > '/sys/bus/pci/devices/0000:00:14.2/power/control';
echo 'auto' > '/sys/bus/pci/devices/0000:06:00.0/power/control';
echo 'auto' > '/sys/bus/pci/devices/0000:00:00.0/power/control';
echo 'auto' > '/sys/bus/pci/devices/0000:0c:00.0/power/control';
echo 'auto' > '/sys/bus/pci/devices/0000:00:1f.5/power/control';
echo 'auto' > '/sys/bus/pci/devices/0000:00:1f.0/power/control';
echo 'auto' > '/sys/bus/pci/devices/0000:00:14.3/power/control';
echo 'auto' > '/sys/bus/pci/devices/0000:00:04.0/power/control';
