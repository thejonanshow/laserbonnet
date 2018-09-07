require "date"

@start_secs = DateTime.parse(`date +"%b %d %T"`).to_time.to_i

def blink
  [1,0,1,0,1,0,1,0,1,0].each do |n|
    `echo #{n} | tee /sys/class/leds/led0/brightness`
    sleep 0.5
  end
end

def laserbonnet_ready
  journalctl_output = `journalctl -u laserbonnet | tail -n 1`.chomp

  month, day, time, _, _, *log_line = journalctl_output.split
  log_line = log_line.join(" ")

  journal_secs = DateTime.parse("#{month} #{day} #{time}").to_time.to_i

  expected_line = "Laserbonnet is listening..."

  @start_secs <= journal_secs && log_line == expected_line
end

until (laserbonnet_ready)
  puts "Waiting for laserbonnet to come online..."
  sleep 1
end

blink
