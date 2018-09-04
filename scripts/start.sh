source /usr/local/share/chruby/chruby.sh
chruby 2.5.1

git pull origin master
bundle install

ruby /home/pi/src/laserbonnet/start_laserbonnet.rb < bonnet_pipe
