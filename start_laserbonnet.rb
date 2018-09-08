require "./laserbonnet"

puts "Laserbonnet is listening..."
Redis.new.publish("system", "start_laserbonnet")
Laserbonnet.new.listen
puts "Laserbonnet finished listening"
