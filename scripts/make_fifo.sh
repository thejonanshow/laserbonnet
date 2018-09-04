#!/bin/bash
if [[ -e /home/pi/src/laserbonnet/bonnet_pipe ]]; then
  echo bonnet_pipe already exists
else
  mkfifo /home/pi/src/laserbonnet/bonnet_pipe
  chown pi:pi /home/pi/src/laserbonnet/bonnet_pipe
  echo created bonnet_pipe
fi
