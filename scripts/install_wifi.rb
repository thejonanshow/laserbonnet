#!/usr/bin/env ruby

require 'yaml'
config = YAML::load_file(File.join(__dir__, '..', 'config', 'production.yaml'))

output = "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev"
config["wifi"].each do |item|
  output << "
network={
  ssid=\"#{item["ssid"]}\"
  psk=\"#{item["psk"]}\"
  key_mgmt=WPA-PSK
}"
end

open('/etc/wpa_supplicant/wpa_supplicant.conf', 'w') { |f|
  f.puts output
}

`wpa_cli -i wlan0 reconfigure`
