require "eventmachine"
require "em-http-request"
require "em-http/middleware/json_response"
require "multipart_body"
require "em-eventsource"

require_relative "errors"

module EventMachine
  module UCEngine
    # Use response as block
    module EventMachineResponse
      def answer(req, &block)
        response = EM::DefaultDeferrable.new
        req.errback do
          error = UCEngine::Client::HttpError.new(0, "connect error", req.last_effective_url)
          response.fail error
          yield error, nil if block_given?
        end
        req.callback do
          data = req.response
          if data["error"]
            error = UCEngine::Client::UCError.new(req.response_header.status, data["error"], req.last_effective_url)
            response.fail error
            yield error, nil if block_given?
          else
            response.succeed data["result"]
            yield nil, data["result"] if block_given?
          end
        end
        response
      end

      def answer_bool(req, &block)
        answer(req) do |err, result|
          result = (result == "true")
          yield nil, result if block_given?
        end
      end

      def answer_download(req)
        response = EM::DefaultDeferrable.new
        req.errback do
          error = UCEngine::Client::HttpError.new(0, "connect error", req.last_effective_url)
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
            error = UCEngine::Client::HttpError.new(0, "download error")
            response.fail error
            yield error, nil if block_given?
          end
        end
        response
      end

      def answer_connect(http)
        response = EM::DefaultDeferrable.new
        http.errback do
          error = UCEngine::Client::HttpError.new(0, "connect error", http.uri)
          response.fail error
          yield error, nil if block_given?
        end
        http.callback do
          if http.response_header.status >= 500
            error = UCEngine::Client::HttpError.new(http.response_header.status, http.response, http.uri)
            response.fail error
            yield error, nil if block_given?
          else
            data = http.response
            if data['error']
              error = UCEngine::Client::UCError.new(http.response_header.status, data['error'], http.req.uri.to_s)
              response.fail error
              yield error, nil if block_given?
            else
              result = data["result"]
              session = UCEngine::Client::Session.new(self, result["uid"], result["sid"])
              response.succeed session
              yield nil, session if block_given?
            end
          end
        end
        response
      end
    end

    module EventMachineRequest
      def http_request(method, path, params={}, body={}, session=nil, headers=nil, &block)
        opts ||= {:query => params, :body => body, :head => headers}

        key = (method == :get || method == :delete) ? :query : :body
        opts[key].merge!(:uid => self.uid, :sid => self.sid) if self.class == UCEngine::Client::Session

        # TODO: make a em-http-request middleware
        if headers && headers['Content-Type'] == 'application/json'
          opts[key] = opts[key].to_json
        end

        conn = EM::HttpRequest.new(path)
        req = conn.send(method, opts)
        req
      end

      def get(path, params={}, body={}, session=nil, headers=nil)
        http_request(:get, path, params, body, session, headers)
      end

      def post(path, params={}, body={}, session=nil, headers={})
        http_request(:post, path, params, body, session, headers)
      end

      def put(path, params={}, body={}, session=nil, headers={})
        http_request(:put, path, params, body, session, headers)
      end

      def delete(path, params={}, body={}, session=nil, headers={})
        http_request(:delete, path, params, body, session, headers)
      end

      # Perform a post request on the API with a content type application/json
      #
      # @param [String] path
      # @param [Hash] body
      def json_post(path, body)
        http_request(:post, path, {}, body, nil, {'Content-Type' => 'application/json'})
      end
    end

    class Client < ::UCEngine::Client
      include UCEngine::EventMachineResponse
      include UCEngine::EventMachineRequest

      EM::HttpRequest.use EM::Middleware::JSONResponse

      def time(&block)
        Session.new(self, nil, nil).time &block
      end

      # Init EventMachine and init a new instance of U.C.Engine client
      # See #initialize for arguments
      def self.run(*args)
        EM.run {  yield self.new(*args) }
      end

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

      class Session < ::UCEngine::Client::Session
        include UCEngine::EventMachineResponse
        include UCEngine::EventMachineRequest

        # Subscribe to events
        #
        # @param [String] meeting
        # @param [Hash] params
        # @return Subscription
        def subscribe(meeting, params={}, &block)
          params[:mode] = "eventsource"
          params.merge!(:uid => uid, :sid => sid)
          s = Subscription.new(url("/live/#{meeting}"), params)
          time do |err, now|
            s.message do |message|
              block.call(nil, [JSON.parse(message)])
            end
            s.error do |error|
              if s.ready_state != EM::EventSource::CONNECTING
                puts error
                block.call error, nil
              end
            end
            s.start(now)
          end
          s
        end

        # Upload a file in a meeting room
        #
        # @param [String] meeting name
        # @param [File] file
        # @param [Hash] metadata
        def upload(meeting, file, metadata={}, &block)
          partfile = Part.new( :name => 'content',
                               :filename => File.basename(file.path),
                               :body =>  file.read)
          partuid = Part.new( :name => 'uid',
                              :body => uid)
          partsid = Part.new( :name => 'sid',
                              :body => sid)
          parts = [partfile, partsid, partuid]
          parts << metadata.inject([]) { |array, (key, value)|
            array << Part.new( :name => "metadata[#{key}]",
                               :body => value )
          }

          body = MultipartBody.new(parts)

          conn = EM::HttpRequest.new(uce.url "/file/#{meeting}")
          req = conn.post( :head => {'content-type' => "multipart/form-data; boundary=#{body.boundary}"},
                           :body => "#{body.to_s}\r\n")
          answer(req, &block)
        end

        # Download a file
        # The result will a File object
        # uce.download("demo", "myfile") do |err, file|
        #    puts file.open.read
        # end
        #
        # @param [String] meeting
        # @param [String] filename
        def download(meeting, filename, &block)
          answer_download get(url("/file/#{meeting}/#{filename}")), &block
        end

      end
    end
  end
end
