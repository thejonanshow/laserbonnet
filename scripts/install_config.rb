#!/usr/bin/env ruby

require 'fileutils'

config_dir = File.join(File.expand_path('../', __dir__), 'config')

DESTINATIONS = {
  redis: "/etc/redis",
  laserbonnet_rotate: "/etc/logrotate.d"
}

DESTINATIONS.each do |config, directory|
  unless Dir.exists? directory
    raise "Destination directory for #{config} doesn't exist: #{directory}"
  end
end

Dir.glob("#{config_dir}/*").each do |config_file|
  config_name = config_file.split("/").last.split(".").first
  puts config_name

  if DESTINATIONS.key?(config_name.to_sym) then
    destination = DESTINATIONS[config_name.to_sym]
    puts "Copying #{config_file} to #{destination}..."
    FileUtils.cp config_file, destination
  end
end

puts "Config installation complete"
