require 'bundler'
Bundler.require
Dotenv.load

class Laserbonnet
  attr_reader :redis

  def initialize
    system("stty raw -echo")
    @id = get_id
    @redis = Redis.new(url: ENV['REDIS_URL'])
  end

  def send(command)
    redis.publish(ENV['CHANNEL'], { id: @id, command: command }.to_json)
  end

  def get_id
    mac = `./mac_address.sh`.strip
    serial = `cat /proc/cpuinfo  | grep Serial | cut -d ' ' -f 2`.strip
    "#{serial}|#{mac}"
  end

  def listen
    loop do
      char = STDIN.getc
      break if char =~ /q/i
      send_command(char)
    end
  end

  def send_command(char)
    return unless char =~ /(a|b|x|y|s|t|u|d|l|r|1|2)/i
    send(char)
  end
end

Laserbonnet.new.listen

at_exit { system("stty -raw echo") }
