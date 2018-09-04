#!/bin/bash
echo "Stopping services..."
systemctl stop laserbonnet
systemctl stop joybonnet

echo "Copying new service files to systemd..."
cp /home/pi/src/laserbonnet/services/joybonnet.service /etc/systemd/system/joybonnet.service
cp /home/pi/src/laserbonnet/services/laserbonnet.service /etc/systemd/system/laserbonnet.service

echo "Reloading services..."
systemctl daemon-reload

echo "Service installation complete"
