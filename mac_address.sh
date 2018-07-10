# Find MAC of eth0, or wlan0 if eth0 does not exist.

if [ -e /sys/class/net/eth0 ]; then
  MAC=$(cat /sys/class/net/eth0/address)
elif [ -e /sys/class/net/enx* ]; then
  MAC=$(cat /sys/class/net/enx*/address)
else
  MAC=$(cat /sys/class/net/wlan0/address)
fi

echo $MAC
