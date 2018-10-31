source /usr/local/share/chruby/chruby.sh
echo "sourcing chruby"
chruby 2.5.1
echo "changed ruby with chruby"
echo "using $(ruby -v)"

changed=0
cd /home/pi/src/laserbonnet
git pull origin master --dry-run | grep -q -v 'Already up-to-date.' && changed=1

echo "git pull complete"
if [ "$changed" == "1" ]; then
  bundle install

  gpg --batch --yes -r Astro -o /home/pi/src/laserbonnet/.env -d /home/pi/src/laserbonnet/.env.enc
  gpg --batch --yes -r Astro -o /home/pi/src/laserbonnet/config/production.yaml -d /home/pi/src/laserbonnet/config/production.yaml.enc
  echo "updated .env"
fi
echo "starting laserbonnet"
ruby /home/pi/src/laserbonnet/start_laserbonnet.rb
echo "laserbonnet stopped"
