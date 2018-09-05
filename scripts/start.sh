source /usr/local/share/chruby/chruby.sh
echo "sourcing chruby"
chruby 2.5.1
echo "changed ruby with chruby"
echo "using $(ruby -v)"

git pull origin master
bundle install

echo "starting laserbonnet"
ruby /home/pi/src/laserbonnet/start_laserbonnet.rb
echo "laserbonnet stopped"
