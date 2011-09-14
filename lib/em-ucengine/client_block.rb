require_relative "base_client"
require_relative "errors"

module EventMachine
  module UCEngine
    # Use response as block
    module ResponseBlock
      # TODO: Return a deferrable instead of the original request
      def answer(req)
        req.errback {
          yield EM::UCEngine::Client::HttpError.new(0, "connect error", req.last_effective_url), nil if block_given? }
        req.callback do
          data = req.response
          if block_given?
            if data['error']
              yield EM::UCEngine::Client::UCError.new(req.response_header.status, data["error"], req.last_effective_url), nil
            else
              result = data["result"]
              yield nil, result
            end
          end
        end
        req
      end

      def answer_download(req)
        req.errback  { yield EM::UCEngine::Client::HttpError.new(0, "connect error"), nil if block_given? }
        req.callback do
          if block_given?
            if req.response_header.status == 200
              data = req.response
              filename = req.response_header['CONTENT_DISPOSITION']
              file = Tempfile.new(filename)
              file.write(data)
              yield nil, file
            else
              yield EM::UCEngine::Client::HttpError.new(0, "download error")
            end
          end
        end
        req
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
        http.errback  { yield EM::UCEngine::Client::HttpError.new(0, "Socket error"), nil }
        http.callback do
          if http.response_header.status >= 500
            yield EM::UCEngine::Client::HttpError.new(http.response_header.status, http.response), nil
          else
            data = http.response
            if data['error']
              yield EM::UCEngine::Client::UCError.new(http.response_header.status, data["error"]), nil
            else
              result = data["result"]
              yield nil, SessionBlock.new(self, result["uid"], result["sid"])
            end
          end
        end
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
              puts error if s.ready_state != EM::EventSource::CONNECTING
              block.call error, nil
            end
            s.start(time)
          end
          s
        end
      end
    end
  end
end
