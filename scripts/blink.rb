begin
  require "redis"
rescue LoadError => e
  if e.message =~ /redis/
    puts "#{e}: #{e.message}"
    `gem install redis`
    retry
  else
    raise e
  end
end

def blink
  [1,0,1,0,1,0,1,0,1,0].each do |n|
    `echo #{n} | tee /sys/class/leds/led0/brightness`
    sleep 0.5
  end
end

def laserbonnet_ready
  Redis.new.subscribe("system") do |on|
    on.subscribe do |channel, subscriptions|
      puts "Subscribed to #{channel}"
    end

    on.message do |channel, message|
      puts "Message received on #{channel}: #{message}"
      break if message == "start_laserbonnet"
    end

    on.unsubscribe do |channel, subscriptions|
      puts "Unsubscribed from #{channel}"
    end
  end
end

until (laserbonnet_ready)
  puts "Waiting for laserbonnet to come online..."
  sleep 1
end

blink
