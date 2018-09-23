require 'bundler'
Bundler.require
Dotenv.load

require 'thread'
require 'io/console'
require 'socket'
require './local_logger'
require './laser_logger'
require './ansible'

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
    @local_log = LocalLogger.new
    @local_log.puts "Initializing Laserbonnet"
    @remote_log = LaserLogger.new(@local_log)

    @id = get_id
    @log_queue = Queue.new

    uname = `uname`.strip
    if uname =~ /Darwin/
      @env = 'development'
    else
      @env = 'production'
    end

    if @env == 'development'
      puts 'Starting in development mode...'
      redis_url = 'redis://localhost:6379'
      websocket_url = 'ws://localhost:3000/cable'
      puts redis_url
      puts websocket_url
      @joy = nil
    else
      redis_url = ENV['REDIS_URL']
      websocket_url = 'wss://spaceblazer.cloud/cable'
      @joy = TCPSocket.open('localhost', 31879)
    end

    @redis = Redis.new(url: redis_url)
    @channel = ENV['REDIS_CHANNEL']
    @ansible = Ansible.new(id: @id, url: websocket_url, redis: @redis, channel: @channel)

    start_remote_log

    @log_queue << {
      id: @id,
      level: "info",
      line: "online"
    }

    @ansible.send_passport
    send("online")
  rescue => e
    handle_error(e)
  end

  def start_remote_log
    @local_log.puts "Starting remote log"

    Thread.new do
      loop do
        unless @log_queue.empty?
          message = @log_queue.shift

          @remote_log.log(
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

  def get_char
    if @env == 'development'
      char = STDIN.getch.chomp

      if char == 'w'
        char = 'u'
      elsif char == 'a'
        char = 'l'
      elsif char == 's'
        char = 'd'
      elsif char == 'd'
        char = 'r'
      elsif char == ' '
        char = 'b'
      elsif char =~ /(q|\u0003)|\e/i
        char = 'q'
      elsif char == ''
        char = 's'
      elsif char == '1'
        char = '1'
      elsif char == '2'
        char = '2'
      elsif char == 't'
        char = 't'
      elsif char == 'b'
        char = 'b'
      elsif char == 'z'
        char = 'a'
      else
        char = ''
      end
    else
      char = @joy.getc
    end

    char
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

  def listen
    @local_log.puts "Listening..."

    while char = get_char
      char = check_combo(char)
      next if duplicate? char
      break if char =~ /(q|\u0003)/i
      send_command(char)
    end

    @local_log.puts "Stopped listening..."
  rescue => e
    handle_error(e)
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
    @local_log.puts log_line
  end
end
