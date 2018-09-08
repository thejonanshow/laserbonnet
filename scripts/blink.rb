begin
  require "redis"
rescue LoadError => e
  `gem install redis`
end

def blink
  [1,0,1,0,1,0,1,0,1,0].each do |n|
    `echo #{n} | tee /sys/class/leds/led0/brightness`
    sleep 0.5
  end
end

def laserbonnet_ready
  puts "Subscribing to redis..."

  Redis.new.subscribe("system") do |on|
    on.subscribe do |channel, subscriptions|
      puts "Subscribed to #{channel}"
    end

    on.message do |channel, message|
      puts "Message received on #{channel}: #{message}"
      break if message == "start_laserbonnet"

      if message == "start_laserbonnet"
        blink
        exit
      end
    end

    on.unsubscribe do |channel, subscriptions|
      puts "Unsubscribed from #{channel}"
    end
  end
end
