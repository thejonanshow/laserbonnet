function fail {
  echo $1 >&2
  exit 1
}

function retry {
  local n=1
  local max=10
  local delay=5
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        echo "Unable to reach Google. Attempt $n/$max:"
        sleep $delay;
      else
        fail "Network test failed after $n attempts."
      fi
    }
  done
}

retry wget -q --tries=10 --timeout=20 --spider http://google.com

if [[ $? -eq 0 ]]; then
  echo "network is online"

  cd /home/pi/src/laserbonnet
  git pull origin master
  echo "git pull complete"

  /home/pi/src/laserbonnet/scripts/install_config.rb
  /home/pi/src/laserbonnet/scripts/install_services.rb
fi
