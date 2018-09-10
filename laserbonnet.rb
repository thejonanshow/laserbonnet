require 'bundler'
Bundler.require
Dotenv.load

require 'thread'
require 'io/console'
require 'fileutils'
require 'socket'

class LocalLogger
  def initialize
    FileUtils.mkdir_p "./logs"
    @file = File.open("./logs/laserbonnet.log", "a+")
  end

  def puts(line)
    @file.puts "#{Time.now} - #{line}"
  end
end

LOG = LocalLogger.new

class LaserLogger
  def initialize
    LOG.puts "Initializing LaserLogger"

    @client = Faraday.new(url: "http://logblazer-production.herokuapp.com") do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter Faraday.default_adapter
    end
  end

  def log(id:, line:, level:)
    LOG.puts "Sending logs to logblazer: #{level} - #{line}"
    data = {
      source: "laserbonnet",
      id: id,
      level: level,
      line: line
    }
    LOG.puts data
    @client.post('/loglines/create', data)
  end
end

class Laserbonnet
  attr_reader :redis

  CHARACTER_WHITELIST = /(a|b|x|y|s|t|o|w|u|d|l|r|1|2|3|4|5|6|7|8|9|0|-|=)/i

  def initialize
    LOG.puts "Initializing Laserbonnet"
    @id = get_id
    @log_queue = Queue.new
    @logger = LaserLogger.new

    @joy = TCPSocket.open('localhost', 31879)

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
    LOG.puts "Starting remote logger"

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
    redis.publish(ENV['REDIS_CHANNEL'], { id: @id, command: command }.to_json)
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
    LOG.puts "Listening..."

    while char = @joy.getc
      break if char =~ /(q|\u0003)/i
      send_command(char)
    end

    LOG.puts "Stopped listening..."
  rescue => e
    @log_queue << {
      id: @id,
      level: "error",
      line: "#{e.class}: #{e}"
    }
    LOG.puts "#{e.class}: #{e}"
  end

  def send_command(char)
    return unless char =~ CHARACTER_WHITELIST
    send(char)
  end
end
