require_relative "base_client"
require_relative "errors"

module EventMachine
  module UCEngine
    class ClientFiber
      include BaseClient

      # Get server time
      def time(&block)
        SessionFiber.new(self, nil, nil).time &block
      end

      def handle_connect(http)
        f = Fiber.current
        http.errback  { f.resume EM::UCEngine::Client::HttpError.new(0, "Socket error") }
        http.callback do
          if http.response_header.status >= 500
            f.resume EM::UCEngine::Client::HttpError.new(http.response_header.status, http.response)
          else
            data = http.response
            if data['error']
              f.resume EM::UCEngine::Client::UCError.new(http.response_header.status, data["error"])
            else
              result = data["result"]
              session = SessionFiber.new(self, result["uid"], result["sid"])
              f.resume session
            end
          end
        end
        result = Fiber.yield
        raise result if result.is_a? EM::UCEngine::Client::HttpError
        result
      end

      class SessionFiber < BaseClient::BaseSession
        # Check user ACL
        #
        # @param [String] uid
        # @param [String] action
        # @param [String] object
        # @param [Hash] conditions
        # @param [String] meeting name
        def user_can(uid, action, object, conditions={}, location="")
          result = get("/user/#{uid}/can/#{action}/#{object}/#{location}", :conditions => conditions)
          result == "true"
        end

        def answer(req)
          f = Fiber.current
          req.errback { f.resume EM::UCEngine::Client::HttpError.new(0, "connect error", req.last_effective_url) }
          req.callback do
            data = req.response
            if data['error']
              f.resume EM::UCEngine::Client::UCError.new(req.response_header.status, data["error"], req.last_effective_url)
            else
              result = data["result"]
              f.resume result
            end
          end
          result = Fiber.yield
          raise result if result.is_a? EM::UCEngine::Client::HttpError
          result
        end

        def answer_download(req)
          f = Fiber.current
          req.errback  { f.resume EM::UCEngine::Client::HttpError.new(0, "connect error"), nil }
          req.callback do
            if req.response_header.status == 200
              data = req.response
              filename = req.response_header['CONTENT_DISPOSITION']
              file = Tempfile.new(filename)
              file.write(data)
              f.resume file
            end
          end
          Fiber.yield
        end
      end
    end
  end
end
