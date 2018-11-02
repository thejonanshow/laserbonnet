require 'faraday'
require 'thread'
require 'binding_of_caller'

class LaserLogger
  def initialize(local_log, id, config)
    @local_log = local_log
    @local_log.log "Initializing LaserLogger"
    @config = config
    @id = id

    @client = Faraday.new(url: @config["logblazer"]["url"]) do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter Faraday.default_adapter
    end
  end

  def log(level, line)
    caller_class = binding.of_caller(1).eval('self.class.name')
    caller_method_type = "#"
    if caller_class == 'Class' then
      caller_class = binding.of_caller(1).eval('self.name')
      caller_method_type = "."
    end
    caller_method = binding.of_caller(1).eval('__method__')
    method_name = "#{caller_class}#{caller_method_type}#{caller_method}"
    @local_log.log "logblazer: #{method_name} #{level} - #{line}"
    data = {
      source: "laserbonnet",
      api_key: @config["logblazer"]["url"],
      api_ver: @config["logblazer"]["version"],
      method: method_name,
      id: @id,
      level: level,
      line: line
    }
    @client.post('/loglines/create', data)
  end
end
