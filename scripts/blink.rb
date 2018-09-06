require "date"

@start_secs = DateTime.parse(`date +"%b %d %T"`).to_time.to_i + 10

def blink
  [1,0,1,0,1,0,1,0,1,0].each do |n|
    `echo #{n} | tee /sys/class/leds/led0/brightness`
    sleep 0.5
  end
end

def laserbonnet_ready
  journalctl_output = `journalctl -u laserbonnet | tail -n 1`.chomp

  journal_secs = DateTime.parse(journalctl_output[0..14]).to_time.to_i

  log_line = journalctl_output.split(/bash\[\d+\]: /).last
  expected_line = "Laserbonnet is listening..."

  puts @start_secs - journal_secs
  @start_secs <= journal_secs && log_line == expected_line
end

until (laserbonnet_ready)
  puts "Waiting for laserbonnet to come online..."
  sleep 1
end

blink
