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

  changed=0
  cd /home/pi/src/laserbonnet
  git pull origin master --dry-run | grep -q -v 'Already up-to-date.' && changed=1
  echo "git pull complete"
  if [ "$changed" == "1" ]; then
    echo "repo changes, updating..."
    git pull origin master
	/home/pi/src/laserbonnet/scripts/install_config.rb
	/home/pi/src/laserbonnet/scripts/install_services.rb
    /home/pi/src/laserbonnet/scripts/install_wifi.rb
  else
    echo "no repo changes, skipping update"
  fi
fi
