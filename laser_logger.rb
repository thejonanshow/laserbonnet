require 'faraday'
require 'thread'

class LaserLogger
  def initialize(local_log)
    @local_log = local_log
    @local_log.puts "Initializing LaserLogger"

    @client = Faraday.new(url: "http://logblazer-production.herokuapp.com") do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter Faraday.default_adapter
    end
  end

  def log(id:, line:, level:)
    @local_log.puts "Sending logs to logblazer: #{level} - #{line}"
    data = {
      source: "laserbonnet",
      id: id,
      level: level,
      line: line
    }
    @local_log.puts data
    @client.post('/loglines/create', data)
  end
end
