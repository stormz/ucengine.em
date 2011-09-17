require_relative "base_client"
require_relative "errors"

module EventMachine
  module UCEngine
    # Use response as block
    module ResponseBlock
      def answer(req, &block)
        response = EM::DefaultDeferrable.new
        req.errback do
          error = EM::UCEngine::Client::HttpError.new(0, "connect error", req.last_effective_url)
          response.fail error
          yield error, nil if block_given?
        end
        req.callback do
          data = req.response
          if data["error"]
            error = EM::UCEngine::Client::UCError.new(req.response_header.status, data["error"], req.last_effective_url)
            response.fail error
            yield error, nil if block_given?
          else
            response.succeed data["result"]
            yield nil, data["result"] if block_given?
          end
        end
        response
      end

      def answer_download(req)
        response = EM::DefaultDeferrable.new
        req.errback do
          error = EM::UCEngine::Client::HttpError.new(0, "connect error", req.last_effective_url)
          response.fail error
          yield error, nil if block_given?
        end
        req.callback do
          if req.response_header.status == 200
            data = req.response
            filename = req.response_header['CONTENT_DISPOSITION']
            file = Tempfile.new(filename)
            file.write(data)
            response.succeed file
            yield nil, file if block_given?
          else
            error = EM::UCEngine::Client::HttpError.new(0, "download error")
            response.fail error
            yield error, nil if block_given?
          end
        end
        response
      end
    end

    class ClientBlock
      include BaseClient

      # Represent a subscription to the U.C.Engine API
      # Use #subscribe to create a new one
      class Subscription < EM::EventSource
        # Start subscription
        def start(start)
          @query[:start] = start
          super()
        end

        # Cancel subscription
        def cancel
          close
          yield if block_given?
        end
      end

      # Get server time
      def time(&block)
        SessionBlock.new(self, nil, nil).time &block
      end

      def handle_connect(http)
        response = EM::DefaultDeferrable.new
        http.errback do
          error = EM::UCEngine::Client::HttpError.new(0, "connect error")
          response.fail error
          yield error, nil if block_given?
        end
        http.callback do
          error = EM::UCEngine::Client::HttpError.new(http.response_header.status, http.response)
          if http.response_header.status >= 500
            response.fail error
            yield error, nil if block_given?
          else
            data = http.response
            if data['error']
              error = EM::UCEngine::Client::UCError.new(http.response_header.status, data["error"])
              response.fail error
              yield error, nil if block_given?
            else
              result = data["result"]
              session = SessionBlock.new(self, result["uid"], result["sid"])
              response.succeed session
              yield nil, session if block_given?
            end
          end
        end
        response
      end

      class SessionBlock < BaseClient::BaseSession
        include ResponseBlock
        # Batch create users
        #
        # @param [Array] users
        def create_users(users, &block)
          cpt = users.length
          users.each do |user|
            create_user(user) do
              cpt -= 1
              if cpt == 0
                yield block
              end
            end
          end
        end

        # Subscribe to events
        #
        # @param [String] meeting
        # @param [Hash] params
        # @return Subscription
        def subscribe(meeting, params={}, &block)
          params[:mode] = "eventsource"
          params.merge!(:uid => uid, :sid => sid)
          s = Subscription.new(uce.url("/live/#{meeting}"), params)
          time do |err, time|
            s.message do |message|
              block.call(nil, [JSON.parse(message)])
            end
            s.error do |error|
              if s.ready_state != EM::EventSource::CONNECTING
                puts error
                block.call error, nil
              end
            end
            s.start(time)
          end
          s
        end
      end
    end
  end
end
