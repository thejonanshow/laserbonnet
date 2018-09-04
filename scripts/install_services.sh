systemctl stop laserbonnet
systemctl stop joybonnet
cp /home/pi/src/laserbonnet/services/joybonnet.service /etc/systemd/system/joybonnet.service
cp /home/pi/src/laserbonnet/services/laserbonnet.service /etc/systemd/system/laserbonnet.service
systemctl daemon-reload
