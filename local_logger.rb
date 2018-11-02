require 'fileutils'

class LocalLogger
  def initialize(config)
    @config = config
    FileUtils.mkdir_p "./logs"
    @file = File.open("./logs/laserbonnet.log", "a+")
  end

  def log(line)
    @file.puts "#{Time.now} - #{line}"
    puts line
  end
end
