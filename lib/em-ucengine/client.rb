require "eventmachine"
require "em-http-request"
require "multipart_body"
require "em-http/middleware/json_response"
require "em-eventsource"
require "json"

module EventMachine
  module UCEngine
    # U.C.Engine client
    class Client
      class HttpError
        attr_reader :code, :description

        def initialize code, description
          @code = code
          @description = description
        end
      end

      class UCError < HttpError
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

      # Init EventMachine and init a new instance of U.C.Engine client
      # See #initialize for arguments
      def self.run(*args)
        EM.run { yield self.new(*args) }
      end

      # Create a new U.C.Engine client
      #
      # @param [String] Host of the U.C.Engine instance
      # @param [Number] Port of the U.C.Engine instance
      # @param [String] Entry point of the API
      # @param [String] Version of U.C.Engine API
      def initialize(host="localhost", port=5280, api_root="/api", api_version="0.6")
        @host = host
        @port = port
        @root = api_root
        @version = api_version

        EM::HttpRequest.use EM::Middleware::JSONResponse
      end

      # Get server time
      def time
        Session.new(self, nil, nil).time { |err, time| yield err, time }
      end

      # Connect to U.C.Engine
      #
      # @param [String] User name
      # @param [String] Password
      # @param [Hash] Metadata of the user
      def connect(user, password, metadata=nil)
        body = { "name" => user, "credential" => password }
        body["metadata"] = metadata if metadata
        http = EM::HttpRequest.new(url "/presence").post :body => body
        http.errback  { yield HttpError.new(0, "Socket error"), nil }
        http.callback do
          if http.response_header.status >= 500
            yield HttpError.new(http.response_header.status, http.response), nil
          else
            data = http.response
            if data['error']
              yield UCError.new(http.response_header.status, data["error"]), nil
            else
              result = data["result"]
              yield nil, Session.new(self, result["uid"], result["sid"])
            end
          end
        end
      end

      # Create a user
      #
      # @param [Hash] data
      def create_user(data)
        post("/user", data) { |err, result| yield err, result if block_given? }
      end

      # Format url to api
      #
      # @param [String] Path of the method
      def url(path)
        "http://#{@host}:#{@port}#{@root}/#{@version}#{path}"
      end

      # Session represent the U.C.Engine client with and sid and uid
      # See #connect
      class Session < Struct.new(:uce, :uid, :sid)

        ### Time - http://docs.ucengine.org/api.html#time ###

        # Get server time
        def time(&block)
          get("/time", &block)
        end

        ### Presence - http://docs.ucengine.org/api.html#authentication ###

        # Get infos on the presence
        #
        # @param [String] Sid
        def presence(sid, &block)
          get("/presence/#{sid}", &block)
        end

        # Disconnect a user
        #
        # @param [String] Sid
        def disconnect(sid, &block)
          delete("/presence/#{sid}", &block)
        end

        ### Users - http://docs.ucengine.org/api.html#user ###

        # List users
        def users(&block)
          get("/user", &block)
        end

        # Get user info
        #
        # @param [String] uid
        def user(uid, &block)
          get("/user/#{uid}", &block)
        end

        # Create user
        #
        # @param [Hash] data
        def create_user(data, &block)
          post("/user", data, &block)
        end

        # Update user
        #
        # @param [String] uid
        # @param [Hash] data
        def update_user(uid, data, &block)
          put("/user/#{uid}", data, &block)
        end

        # Delete a user
        #
        # @param [String] uid
        def delete_user(uid, &block)
          delete("/user/#{uid}", &block)
        end

        # Check user ACL
        #
        # @param [String] uid
        # @param [String] action
        # @param [String] object
        # @param [Hash] conditions
        # @param [String] meeting name
        def user_can(uid, action, object, conditions={}, location="")
          get("/user/#{uid}/can/#{action}/#{object}/#{location}", :conditions => conditions) do |err, result|
            yield err, result == "true" if block_given?
          end
        end

        ### General infos - http://docs.ucengine.org/api.html#infos ###

        # Get domain infos
        def infos(&block)
          get("/infos", &block)
        end

        # Update domain infos
        #
        # @param [Hash] metadata
        def update_infos(metadata, &block)
          put("/infos", :metadata => metadata, &block)
        end

        ### Meetings - http://docs.ucengine.org/api.html#meeting ###

        # List meetings
        #
        # @param [String] status (upcoming, opened, closed or all)
        def meetings(status=nil, &block)
          get("/meeting/#{status}", &block)
        end

        # Get meeting
        #
        # @param [String] meeting
        def meeting(meeting, &block)
          get("/meeting/all/#{meeting}", &block)
        end

        # Create a meeting
        #
        # @param [String] meeting name
        # @param [Hash] metadata
        def create_meeting(meeting, body={}, &block)
          body.merge!(:name => meeting)
          post("/meeting/all", body, &block)
        end

        # Update a meeting
        #
        # @param [String] meeting name
        # @param [Hash] metadata
        def update_meeting(meeting, body={}, &block)
          put("/meeting/all/#{meeting}", body, &block)
        end

        ### Rosters - http://docs.ucengine.org/api.html#join-a-meeting ###

        # List users on the meeting
        #
        # @param [String] meeting
        def roster(meeting, &block)
          get("/meeting/all/#{meeting}/roster", &block)
        end

        # Join the meeting
        #
        # @param [String] meeting
        def join_roster(meeting, &block)
          post("/meeting/all/#{meeting}/roster", &block)
        end

        # Quit the meeting
        #
        # @param [String] meeting
        # @param [String] uid
        def quit_roster(meeting, uid=nil, &block)
          delete("/meeting/all/#{meeting}/roster/#{uid || @uid}", &block)
        end

        ### Events - http://docs.ucengine.org/api.html#events ###

        # Get events
        #
        # @param [String] meeting
        # @param [Hash] params
        def events(meeting=nil, params={}, &block)
          get("/event/#{meeting}", params, &block)
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
            end
            s.start(time)
          end
          s
        end

        # Publish event
        #
        # @param [String] type
        # @param [String] meeting
        # @param [Hash] metadata
        def publish(type, meeting=nil, metadata=nil, parent=nil, &block)
          args = { :type => type, :uid => uid, :sid => sid }
          args[:parent] = parent if parent
          args[:metadata] = metadata if metadata
          json_post("/event/#{meeting}", args, &block)
        end

        # Get event
        #
        # @param [String] id
        def event(id, &block)
          # Fixme: remove meeting fake param on the 0.7 release
          get("/event/meeting/#{id}", {}, &block)
        end

        # Search
        #
        # @param [Hash] params
        def search(params, &block)
          get("/search/event/", params, &block)
        end

        ### Files - http://docs.ucengine.org/api.html#upload-a-file ###

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
          req = prepare_request(:get, "/file/#{meeting}/#{filename}")
          answer_download(req, &block)
        end

        # Delete a file
        #
        # @param [String] meeting
        # @param [String] filename
        def delete_file(meeting, filename, &block)
          delete("/file/#{meeting}/#{filename}", &block)
        end

        # List files on a meeting room
        #
        # @param [String] meeting
        # @param [Hash] params
        def files(meeting, params={}, &block)
          get("/file/#{meeting}", params, &block)
        end

        ### Roles - http://docs.ucengine.org/api.html#roles ###

        # Create a role
        #
        # @param [Hash] data
        def create_role(data, &block)
          post("/role/", data, &block)
        end

        # Delete a role
        #
        # @param [String] name
        def delete_role(name, &block)
          delete("/role/#{name}", &block)
        end

        # Set a role to a user
        #
        # @param [String] uid
        # @param [Hash] params
        def user_role(uid, params={}, &block)
          post("/user/#{uid}/roles", params, &block)
        end

        def get(path, params={}, &block)
          http_request(:get, path, :query => params, &block)
        end

        def post(path, body=nil, &block)
          http_request(:post, path, :body => body, &block)
        end

        def json_post(path, args, &block)
          req = EM::HttpRequest.new(uce.url path).post(
                                                       :body => args.to_json,
                                                       :head => {'Content-Type' => 'application/json'})
          answer(req, &block)
        end

        def put(path, body=nil, &block)
          http_request(:put, path, :body => body, &block)
        end

        def delete(path, &block)
          http_request(:delete, path, &block)
        end

        def answer(req)
          req.errback  { yield HttpError.new(0, "connect error"), nil if block_given? }
          req.callback do
            data = req.response
            if block_given?
              if data['error']
                yield UCError.new(req.response_header.status, data["error"]), nil
              else
                result = data["result"]
                yield nil, result
              end
            end
          end
          req
        end

        def answer_download(req)
          req.errback  { yield HttpError.new(0, "connect error"), nil if block_given? }
          req.callback do
            if block_given?
              if req.response_header.status == 200
                data = req.response
                filename = req.response_header['CONTENT_DISPOSITION']
                file = Tempfile.new(filename)
                file.write(data)
                yield nil, file
              end
            end
          end
          req
        end

        def http_request(method, path, opts={}, &block)
          req = prepare_request(method, path, opts)
          answer(req, &block)
        end

        def prepare_request(method, path, opts={})
          key = (method == :get || method == :delete) ? :query : :body
          opts[key] ||= {}
          opts[key].merge!(:uid => uid, :sid => sid)

          conn = EM::HttpRequest.new(uce.url path)
          req = conn.send(method, opts)
        end
      end
    end
  end
end
