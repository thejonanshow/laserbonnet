require 'bundler'
Bundler.require
Dotenv.load

require 'thread'
require 'io/console'

class LaserLogger
  def initialize
    @client = Faraday.new(url: "http://logblazer-production.herokuapp.com") do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter Faraday.default_adapter
    end
  end

  def log(id:, line:, level:)
    data = {
      source: "laserbonnet",
      id: id,
      level: level,
      line: line
    }
    puts data
    @client.post('/loglines/create', data)
  end
end

class Laserbonnet
  attr_reader :redis

  def initialize
    @id = get_id
    @log_queue = Queue.new
    @logger = LaserLogger.new

    start_logger

    @log_queue << {
      id: @id,
      level: "info",
      line: "online"
    }

    @redis = Redis.new(url: ENV['REDIS_URL'])
    send("online")
  rescue => e
    @log_queue << {
      id: @id,
      level: "error",
      line: "#{e.class}: #{e}"
    }
  end

  def start_logger
    Thread.new do
      loop do
        unless @log_queue.empty?
          message = @log_queue.shift

          @logger.log(
            id: message[:id],
            line: message[:line],
            level: message[:level]
          )
        end

        sleep 0.1
      end
    end
  end

  def send(command)
    redis.publish(ENV['CHANNEL'], { id: @id, command: command }.to_json)
  rescue => e
    @log_queue << {
      id: @id,
      level: "error",
      line: "#{e.class}: #{e}"
    }
  end

  def get_id
    mac = `./scripts/mac_address.sh`.strip
    serial = get_serial
    "#{serial}|#{mac}"
  end

  def get_serial
    if File.exists? '/proc/cpuinfo'
      `cat /proc/cpuinfo  | grep Serial | cut -d ' ' -f 2`.strip
    else
      "unknown_serial"
    end
  end

  def listen
    loop do
      char = STDIN.getch
      break if char =~ /(q|\u0003)/i
      send_command(char)
    end
  rescue => e
    @log_queue << {
      id: @id,
      level: "error",
      line: "#{e.class}: #{e}"
    }
  end

  def send_command(char)
    return unless char =~ /(a|b|x|y|s|t|u|d|l|r|1|2|7|8|9|0)/i
    send(char)
  end
end
