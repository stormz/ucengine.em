require "eventmachine"
require "em-http-request"
require "em-http/middleware/json_response"
require "em-synchrony"
require "multipart_body"
require "em-eventsource"
require "uri"
require "json"

require_relative "client_block"
require_relative "client_fiber"

module EventMachine
  module UCEngine
    module Client

      def self.new_with_fiber(*args)
        ClientFiber.new(*args)
      end

      def self.new(*args)
        ClientBlock.new(*args)
      end

      # Init EventMachine and init a new instance of U.C.Engine client
      # See #initialize for arguments
      def self.run(*args)
        EM.run { yield self.new(*args) }
      end

      # Init synchrony and EventMachine and init a new instance of U.C.Engine client
      # See #initialize for arguments
      def self.synchrony(*args)
        EM.synchrony {
          instance = self.new_with_fiber(*args)
          yield instance
        }
      end
    end
  end
end
