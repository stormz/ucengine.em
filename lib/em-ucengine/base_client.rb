module EventMachine
  module UCEngine
    # U.C.Engine client
    module BaseClient
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
      def time(&block)
        Session.new(self, nil, nil).time &block
      end

      # Connect to U.C.Engine
      #
      # @param [String] User name
      # @param [String] Password
      # @param [Hash] Metadata of the user
      def connect(user, password, metadata=nil, &block)
        body = { "name" => user, "credential" => password }
        body["metadata"] = metadata if metadata
        http = EM::HttpRequest.new(url "/presence").post :body => body
        handle_connect(http, &block)
      end

      # Create a user
      #
      # @param [Hash] data
      def create_user(data)
        post("/user", data, &block)
      end

      # Format url to api
      #
      # @param [String] Path of the method
      def url(path)
        URI.escape "http://#{@host}:#{@port}#{@root}/#{@version}#{path}"
      end

      # Session represent the U.C.Engine client with and sid and uid
      # See #connect
      class BaseSession < Struct.new(:uce, :uid, :sid)
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

        # Perform a get request on the API
        #
        # @param [String] path
        # @param [Hash] params
        def get(path, params={}, &block)
          http_request(:get, path, :query => params, &block)
        end

        # Perform a post request on the API
        #
        # @param [String] path
        # @param [Hash] body
        def post(path, body=nil, &block)
          http_request(:post, path, :body => body, &block)
        end

        # Perform a post request on the API with a content type application/json
        #
        # @param [String] path
        # @param [Hash] body
        def json_post(path, body, &block)
          req = EM::HttpRequest.new(uce.url path).post(
                                                       :body => body.to_json,
                                                       :head => {'Content-Type' => 'application/json'})
          answer(req, &block)
        end

        # Perform a put request on the API
        #
        # @param [String] path
        # @param [Hash] body
        def put(path, body=nil, &block)
          http_request(:put, path, :body => body, &block)
        end

        # Perform a delete request on the API
        #
        # @param [String] path
        def delete(path, &block)
          http_request(:delete, path, &block)
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
