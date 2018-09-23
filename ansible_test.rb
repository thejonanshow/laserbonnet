require './ansible'
require 'dotenv'
Dotenv.load

@id = "NCC1701D"

@config = {
  production: {
    websocket_url: "wss://spaceblazer.cloud/cable",
    redis_url: ENV['REDIS_URL']
  },
  local: {
    websocket_url: "ws://localhost:3000/cable",
    redis_url: "redis://localhost:6379"
  }
}

@ansibles = {}

def setup_ansibles
  kill_ansibles

  @config.keys.each do |env|
    puts "Setting ansible in #{env}"
    @ansibles[env] = Ansible.new(id: @id, url: @config[env][:websocket_url], redis: Redis.new(url: @config[env][:redis_url]))
  end
end

def kill_ansibles
  @ansibles.values.each do |a|
    a.kill
  end
end

input = nil

@env = nil

def select_env
  while @env.nil?
    puts "Select an environment:"
    @config.keys.each.with_index do |key, index|
      puts "#{index + 1}. #{key} - #{@config[key][:websocket_url]}"
    end

    input = gets.chomp.to_i

    if input == 1
      @env = @config.keys[0]
    elsif input == 2
      @env = @config.keys[1]
    else
      puts "Invalid selection, try again."
    end
  end
end

setup_ansibles
select_env

loop do
  while @a.nil?
    @a = @ansibles[@env]
    sleep 1
  end
  @a = @ansibles[@env]

  puts "Your player ID is #{@a.id} in the #{@env} environment"
  puts "Connected to #{@a.url} from #{@a.ip}"
  puts "Redis: #{@config[@env][:redis_url]}"
  puts
  puts "1. Change player ID"
  puts "2. Register player"
  puts "3. Send passport"
  puts "4. Change environment"
  puts "(q)uit"
  puts
  puts "Enter a message to send or a number from the menu:"
  input = gets.chomp

  if input == '1'
    puts "Enter new player ID:"
    @id = gets.chomp
    setup_ansibles
  elsif input == '2'
    @a.register_player(id: @id)
    puts "Registered player #{@id}"
  elsif input == '3'
    @a.send_passport
  elsif input == '4'
    select_env
  elsif input == 'q'
    kill_ansibles
    puts "Thank you for playing!"
    break
  else
    puts "Sending command #{input}"
    @a.send_command(input)
  end
end
