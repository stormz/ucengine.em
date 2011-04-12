require "eventmachine"
require "em-http-request"


module EventMachine
  class UCEngine
    class << self
      attr_accessor :api_root, :api_version
    end
    self.api_root = "/api"
    self.api_version = "0.4"

   def initialize(host="localhost", port=5280)
      @host = host
      @port = port
    end

    def time(&blk)
      url = "http://#{@host}:#{@port}#{self.class.api_root}/#{self.class.api_version}/time"
      http = EM::HttpRequest.new(url).get
      http.callback { yield http.response }
      http.errback  { yield nil }
    end
  end
end
