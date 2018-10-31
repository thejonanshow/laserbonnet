require 'open-uri'
require 'redis'
require 'json'
require 'socket'
require 'openssl'
require './web_socket_client'

class Ansible
  attr_reader :id, :ip, :url, :websocket, :publisher, :connection, :redis

  def initialize(id:, url: 'ws://localhost:3000/cable', redis: nil, channel: ENV['REDIS_CHANNEL'], logger: nil)
    @id = id
    @url = url
    @ip = get_ip
    @redis = redis || Redis.new(url: ENV['REDIS_URL'])
    @channel = channel
    @ready = false
    @logger = logger

    Thread.report_on_exception = true

    @connection = websocket_connection
    @inbound_queue = Queue.new
    @outbound_queue = Queue.new
    @websocket = spawn_websocket(@connection, @inbound_queue, @outbound_queue)
    @publisher = spawn_publisher(@inbound_queue, @websocket)
  end

  def log(msg)
    if @logger =~ nil
      @logger.puts msg
    end
    puts msg
  end

  def kill
    @connection.close
    @websocket.kill
    @publisher.kill
  end

  def register_player(id:)
    @outbound_queue.push(registration_data(id: id))
  end

  def send_command(command)
    @outbound_queue.push(command_data(command))
  end

  def websocket_connection
    WebSocketClient.connect(@url)
  end

  def get_ip
    open('http://whatismyip.akamai.com').read
  end

  def send_passport
    message = "My voice is my passport, verify me: #{@ip}"
    @redis.publish(@channel, message)
  end

  def subscription_data(channel = 'CommandsChannel')
    {
      command: 'subscribe',
      identifier: {
        channel: channel
      }.to_json,
      data: {
        id: @id
      }.to_json
    }.to_json
  end

  def registration_data(id:, channel: 'CommandsChannel')
    {
      command: 'message',
      identifier: {
        channel: 'CommandsChannel'
      }.to_json,
      data: {
        action: 'register_player',
        id: id
      }.to_json
    }.to_json
  end

  def command_data(command)
	{
	  command: 'message',
	  identifier: {
		channel: 'CommandsChannel'
	  }.to_json,
	  data: {
        action: 'echo_command',
		id: @id,
		command: command
	  }.to_json
	}.to_json
  end

  def spawn_publisher(inbound_queue, websocket)
    Thread.new do
      loop do
        frame = inbound_queue.shift
        parsed = JSON.parse(frame.data)
        websocket[:ready] = true if parsed["type"] == "confirm_subscription"
      end
    end
  end

  def spawn_websocket(connection, inbound_queue, outbound_queue)
    subscribe = subscription_data

    Thread.new do
      connection.on :open do
        connection.send subscribe
      end

      connection.on :message do |data|
        inbound_queue.push data
      end

      connection.on :close do |e|
        p e
        exit 1
      end

      connection.on :error do |e|
        p e
      end

      loop do
        next unless @websocket[:ready]
        msg = outbound_queue.shift
        log "outbound: #{msg}"
        connection.send msg
      end
    end
  end
end
