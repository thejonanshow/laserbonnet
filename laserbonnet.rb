require 'bundler'
Bundler.require
Dotenv.load

require 'thread'
require 'io/console'
require 'socket'
require 'yaml'
require './local_logger'
require './laser_logger'
require './ansible'

$stdout.sync = true

class Laserbonnet
  attr_reader :redis

  CHARACTER_WHITELIST = /(a|b|x|y|s|t|o|w|u|d|l|r|1|2|3|4|5|6|7|8|9|0|-|=|n|k)/i
  COMBO_CHARACTERS = /(a|b|x|y|u|d|l|r|s|t|1|2)/i
  COMBOS = {
    'uuddlrlrbas' => 'k',
    '1212' => 'n'
  }

  def initialize(start = true)
    return unless start

    @env = `uname`.strip
    @config = YAML::load_file(File.join(__dir__, 'config', 'production.yaml'))
    @local_log = LocalLogger.new(@config)
    @local_log.log "Initializing Laserbonnet"
    @id = get_id
    @remote_log = LaserLogger.new(@local_log, @id, @config)

    @log_queue = Queue.new

    uname = `uname`.strip
    if uname =~ /Darwin/
      @env = 'development'
    else
      @env = 'production'
    end
    redis_url = @config["redis"]["url"]
    websocket_url = @config["websocket"]

    if @env == 'development'
      puts 'Starting in development mode...'
    else
      websocket_url = 'wss://spaceblazer-tokyo.herokuapp.com/cable'
    end

    @redis = Redis.new(url: redis_url)
    @redis_ipc = Redis.new(url: 'redis://localhost:6379')
    @channel = @config["redis"]["channel"]

    #start_remote_log
    #
    @remote_log.log("info", "online")

    #@log_queue << {
    #  id: @id,
    #  level: "info",
    #  line: "online"
    #}

    @ansible = Ansible.new(id: @id, url: websocket_url, redis: @redis, channel: @channel, remote_log: @remote_log)


    @ansible.send_passport
    send("online")
  rescue => e
    handle_error(e)
  end

  def listen
    @redis_ipc.subscribe('key_state') do |on|
      on.message do |channel, msg|
        puts "#{channel} #{msg}"
        msg = check_combo(msg)
        next if duplicate? msg
        break if msg =~ /(q|\u0003)/i
        send_command(msg)
      end
    end
  end

  def start_remote_log
    @local_log.log "Starting remote log"

    Thread.new do
      loop do
        message = @log_queue.shift
        @remote_log.log(
          id: message[:id],
          line: message[:line],
          level: message[:level]
        )
      end
    end
  end

  def send(command)
    @ansible.send_command(command)
  rescue => e
    handle_error(e)
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

  def duplicate?(char)
    if char =~ /(b|s)/
      @previous_character = char
      return false
    end

    if defined? @previous_character
      duplicate = (char == @previous_character)
    end

    @previous_character = char

    duplicate || false
  end

  def check_combo(char)
    return '' unless char.length == 1

    if !defined?(@history) || @history.nil?
      @history = char
      return char
    end

    unless char =~ COMBO_CHARACTERS
      @history = char
      return char
    end

    patterns = COMBOS.keys
    @history += char

    partial_matches = []
    patterns.each do |pattern|
      matches_so_far = (pattern =~ /#{@history}/)

      if (matches_so_far == 0) && (pattern.length == @history.length)
        @history = char
        return COMBOS[pattern]
      elsif matches_so_far == 0
        partial_matches << @history
      end
    end

    unless partial_matches.any?
      @history = char
    end

    char
  end

  def send_command(char)
    return unless char =~ CHARACTER_WHITELIST
    send(char)
  end

  def handle_error(e)
    p e
    backtrace = e.backtrace.join("\n")
    puts backtrace

    log_line = "#{e.class}: #{e}\n#{backtrace}"

    @log_queue << {
      id: @id,
      level: "error",
      line: log_line
    }
    @local_log.log log_line
  end
end
