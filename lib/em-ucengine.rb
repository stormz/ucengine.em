require "eventmachine"
require "em-http-request"
require "multipart_body"
require 'em-http/middleware/json_response'
require 'json'

module EventMachine

  # U.C.Engine client
  class UCEngine
    class HttpError
      attr_reader :code, :description

      def initialize code, description
        @code = code
        @description = description
      end
    end

    class UCError < HttpError
    end

    class Subscription
      def initialize(session, type, params={}, &block)
        params[:type] = type
        params[:mode] ||= "longpolling"
        @params = params
        @session = session
        @meeting = params[:meeting]
        @on_cancel = Proc.new {}
        @cancelled = false

        @recurse = Proc.new do |err, result|
          if @cancelled
            @on_cancel.call
          else
            if !result.nil? && !result.last.nil?
              block.call(err, result)
              @params[:start] = result.last["datetime"].to_i + 1
            end

            @session.get("/live/#{@meeting}", @params, &@recurse)
          end
        end
      end

      def run
        @session.time do |err, time|
          @params[:start] = time
          @session.get("/event/#{@meeting}", @params, &@recurse)
        end
      end

      def cancel(&block)
        @on_cancel = block
        @cancelled = true
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
    def initialize(host="localhost", port=5280, api_root="/api", api_version="0.5")
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
      def time
        get("/time") { |err, result| yield err, result if block_given? }
      end

      ### Presence - http://docs.ucengine.org/api.html#authentication ###

      # Get infos on the presence
      #
      # @param [String] Sid
      def presence(sid)
        get("/presence/#{sid}") { |err, result| yield err, result if block_given? }
      end

      # Disconnect a user
      #
      # @param [String] Sid
      def disconnect(sid)
        delete("/presence/#{sid}") { |err, result| yield err, result if block_given? }
      end

      ### Users - http://docs.ucengine.org/api.html#user ###

      # List users
      def users
        get("/user") { |err, result| yield err, result if block_given? }
      end

      # Get user info
      #
      # @param [String] uid
      def user(uid)
        get("/user/#{uid}") { |err, result| yield err, result if block_given? }
      end

      # Create user
      #
      # @param [Hash] data
      def create_user(data)
        post("/user", data) { |err, result| yield err, result && result if block_given? }
      end

      # Update user
      #
      # @param [String] uid
      # @param [Hash] data
      def update_user(uid, data)
        put("/user/#{uid}", data) { |err, result| yield err, result if block_given? }
      end

      # Delete a user
      #
      # @param [String] uid
      def delete_user(uid)
        delete("/user/#{uid}") { |err, result| yield err, result if block_given? }
      end

      ### General infos - http://docs.ucengine.org/api.html#infos ###

      # Get domain infos
      def infos
        get("/infos") { |err, result| yield err, result if block_given? }
      end

      # Update domain infos
      #
      # @param [Hash] metadata
      def update_infos(metadata)
        put("/infos", :metadata => metadata) { |err, result| yield err, result if block_given? }
      end

      ### Meetings - http://docs.ucengine.org/api.html#meeting ###

      # List meetings
      #
      # @param [String] status (upcoming, opened, closed or all)
      def meetings(status=nil)
        get("/meeting/#{status}") { |err, result| yield err, result if block_given? }
      end

      # Get meeting
      #
      # @param [String] meeting
      def meeting(meeting)
        get("/meeting/all/#{meeting}") { |err, result| yield err, result if block_given? }
      end

      # Create a meeting
      #
      # @param [String] meeting name
      # @param [Hash] metadata
      def create_meeting(meeting, body={})
        body.merge!(:name => meeting)
        post("/meeting/all", body) { |err, result| yield err, result if block_given? }
      end

      # Update a meeting
      #
      # @param [String] meeting name
      # @param [Hash] metadata
      def update_meeting(meeting, body={})
        put("/meeting/all/#{meeting}", body) { |err, result| yield err, result if block_given? }
      end

      ### Rosters - http://docs.ucengine.org/api.html#join-a-meeting ###

      # List users on the meeting
      #
      # @param [String] meeting
      def roster(meeting)
        get("/meeting/all/#{meeting}/roster") { |err, result| yield err, result if block_given? }
      end

      # Join the meeting
      #
      # @param [String] meeting
      def join_roster(meeting)
        post("/meeting/all/#{meeting}/roster") { |err, result| yield err, result if block_given? }
      end

      # Quit the meeting
      #
      # @param [String] meeting
      # @param [String] uid
      def quit_roster(meeting, uid=nil)
        delete("/meeting/all/#{meeting}/roster/#{uid || @uid}") { |err, result| yield err, result if block_given? }
      end

      ### Events - http://docs.ucengine.org/api.html#events ###

      # Get events
      #
      # @param [String] meeting
      # @param [Hash] params
      def events(meeting=nil, params={})
        params[:_async] = "no"
        get("/event/#{meeting}", params) { |err, result| yield err, result if block_given? }
      end

      # Subscribe to events
      #
      # @param [String] meeting
      # @param [Hash] params
      def subscribe(meeting, params={}, &block)
        s = Subscription.new(self, params[:type], {:meeting => meeting}, &block)
        s.run
        s
      end

      # Publish event
      #
      # @param [String] type
      # @param [String] meeting
      # @param [Hash] metadata
      def publish(type, meeting=nil, metadata=nil)
        args = { :type => type, :uid => uid, :sid => sid }
        args[:metadata] = metadata if metadata
        json_post("/event/#{meeting}", args) { |err, result| yield err, result if block_given? }
      end

      # Search
      #
      # @param [Hash] params
      def search(params)
        get("/search/event/", params) { |err, result| yield err, result if block_given? }
      end

      ### Files - http://docs.ucengine.org/api.html#upload-a-file ###

      # Upload a file in a meeting room
      #
      # @param [String] meeting name
      # @param [File] file
      # @param [Hash] metadata
      def upload(meeting, file, metadata={})
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
                         :body => body.to_s)
        answer req
      end

      ### Roles - http://docs.ucengine.org/api.html#roles ###

      # Create a role
      #
      # @param [Hash] data
      def create_role(data)
        post("/role/", data) { |err, result| yield err, result if block_given? }
      end

      # Delete a role
      #
      # @param [String] name
      def delete_role(name)
        delete("/role/#{name}") { |err, result| yield err, result if block_given? }
      end

      # Set a role to a user
      #
      # @param [String] uid
      # @param [Hash] params
      def user_role(uid, params={})
        post("/user/#{uid}/roles", params){ |err, result| yield err, result if block_given? }
      end

      def get(path, params={})
        http_request(:get, path, :query => params) { |err, result| yield err, result }
      end

      def post(path, body=nil)
        http_request(:post, path, :body => body) { |err, result| yield err, result }
      end

      def json_post(path, args, &block)
        req = EM::HttpRequest.new(uce.url path).post(
                                                     :body => args.to_json,
                                                     :head => {'Content-Type' => 'application/json'})
        answer(req, &block)
      end

      def put(path, body=nil)
        http_request(:put, path, :body => body) { |err, result| yield err, result }
      end

      def delete(path)
        http_request(:delete, path) { |err, result| yield err, result }
      end

      def answer(req)
        req.errback  { yield HttpError.new(0, "connect error"), nil }
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
      end

      def http_request(method, path, opts={}, &block)
        key = (method == :get || method == :delete) ? :query : :body
        opts[key] ||= {}
        opts[key].merge!(:uid => uid, :sid => sid)

        conn = EM::HttpRequest.new(uce.url path)
        req = conn.send(method, opts)
        answer(req, &block)
      end
    end
  end
end
