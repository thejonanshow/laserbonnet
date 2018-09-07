wget -q --tries=10 --timeout=20 --spider http://google.com
if [[ $? -eq 0 ]]; then
  echo "network is online"

  git pull origin master
  echo "git pull complete"

  /home/pi/src/laserbonnet/scripts/install_services.rb
else
  echo "no network connection"
fi
