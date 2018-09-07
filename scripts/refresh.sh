wget -q --tries=10 --timeout=20 --spider http://google.com
if [[ $? -eq 0 ]]; then
  echo "network is online"

  git pull origin master
  bundle install
  echo "git pull complete"

  gpg --batch --yes -r Astro -o /home/pi/src/laserbonnet/.env -d /home/pi/src/laserbonnet/.env.enc
  echo "updated .env"

  /home/pi/src/laserbonnet/scripts/install_services.rb
else
  echo "no network connection"
fi
