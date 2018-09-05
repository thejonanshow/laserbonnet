source /usr/local/share/chruby/chruby.sh
echo "sourcing chruby"
chruby 2.5.1
echo "changed ruby with chruby"
echo "using $(ruby -v)"

git pull origin master
bundle install

gpg --batch --yes -r Astro -o /home/pi/src/laserbonnet/.env -d /home/pi/src/laserbonnet/.env.enc
echo "updated .env"

echo "starting laserbonnet"

echo "Laserbonnet is online!" | wall

ruby /home/pi/src/laserbonnet/start_laserbonnet.rb
echo "laserbonnet stopped"
