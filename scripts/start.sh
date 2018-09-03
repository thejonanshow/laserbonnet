git pull origin master
/usr/local/bin/chruby-exec ruby-2.5.1 -- bundle install
/usr/local/bin/chruby-exec ruby-2.5.1 -- bundle exec /home/pi/src/start_laserbonnet.rb
