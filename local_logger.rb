require 'fileutils'

class LocalLogger
  def initialize
    FileUtils.mkdir_p "./logs"
    @file = File.open("./logs/laserbonnet.log", "a+")
  end

  def puts(line)
    @file.puts "#{Time.now} - #{line}"
  end
end
