require "/home/pi/.gem/ruby/2.5.1/gems/redis-4.0.2/lib/redis"

def blink
  [1,0,1,0,1,0,1,0,1,0].each do |n|
    `echo #{n} | tee /sys/class/leds/led0/brightness`
    sleep 0.5
  end
end

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
