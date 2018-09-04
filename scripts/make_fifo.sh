#!/bin/bash
if [[ -e bonnet_pipe ]]; then
  echo bonnet_pipe already exists
else
  mkfifo bonnet_pipe
  echo created bonnet_pipe
fi
