#!/usr/bin/env ruby

require 'fileutils'

services_dir = File.join(File.expand_path('../', __dir__), 'services')
systemd_path = Dir.exists?("/etc/systemd/system/") ? "/etc/systemd/system" : "/tmp"

local = systemd_path == "/tmp"

Dir.each_child(services_dir) do |service_name|
  service_file = File.join(services_dir, service_name)

  puts "Stopping #{service_name}..."
  `systemctl stop #{service_name}` unless local

  puts "Copying #{service_file} to #{systemd_path}..."
  FileUtils.cp service_file, systemd_path

  puts "Enabling #{service_name}..."
  `systemctl enable #{service_name}` unless local
end

puts "Reloading services..."
`systemctl daemon-reload` unless local

puts "Service installation complete"
