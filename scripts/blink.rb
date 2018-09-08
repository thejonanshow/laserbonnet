begin
  require "redis"
rescue LoadError => e
  puts "We couldn't find redis"
  puts "Trying to install it"
  puts `gem install redis`
  puts "Maybe it installed?"
end

def blink
  [1,0,1,0,1,0,1,0,1,0].each do |n|
    `echo #{n} | tee /sys/class/leds/led0/brightness`
    sleep 0.5
  end
end

puts "Subscribing to redis..."

begin
  Redis.new.subscribe("system") do |on|
    on.subscribe do |channel, subscriptions|
      puts "Subscribed to #{channel}"
    end

    on.message do |channel, message|
      puts "Message received on #{channel}: #{message}"

      if message == "start_laserbonnet"
        blink
        exit
      end
    end

    on.unsubscribe do |channel, subscriptions|
      puts "Unsubscribed from #{channel}"
    end
  end
rescue => e
  puts "It's broken"
  puts e
end
