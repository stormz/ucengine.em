require "eventmachine"
require "em-http-request"
require "multipart_body"
require "yajl"

# TODO: remove after em-http-request@1.0.0beta3
module EventMachine
  module Middleware
    class JSONResponse
      def response(resp)
        body = Yajl::Parser.parse(resp.response)
        resp.response = body
      end
    end
  end
end

module EventMachine

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

    def self.run(*args)
      EM.run { yield self.new(*args) }
    end

    def initialize(host="localhost", port=5280, api_root="/api", api_version="0.5")
      @host = host
      @port = port
      @root = api_root
      @version = api_version
    end

    def time
      Session.new(self, nil, nil).time { |err, time| yield err, time }
    end

    def connect(user, password, metadata=nil)
      body = { "name" => user, "credential" => password }
      body["metadata"] = metadata if metadata
      http = EM::HttpRequest.new(url "/presence").post :body => body
      http.errback  { yield HttpError.new(0, "Socket error"), nil }
      http.callback do
        if http.response_header.status >= 500
          yield HttpError.new(http.response_header.status, http.response), nil
        else
          data = Yajl::Parser.parse(http.response)
          if data['error']
            yield UCError.new(http.response_header.status, data["error"]), nil
          else
            result = data["result"]
            yield nil, Session.new(self, result["uid"], result["sid"])
          end
        end
      end
    end

    def create_user(data)
        post("/user", data) { |err, result| yield err, result if block_given? }
    end

    def url(path)
      "http://#{@host}:#{@port}#{@root}/#{@version}#{path}"
    end

    class Session < Struct.new(:uce, :uid, :sid)

      ### Time - http://docs.ucengine.org/api.html#time ###

      def time
        get("/time") { |err, result| yield err, result if block_given? }
      end

      ### Presence - http://docs.ucengine.org/api.html#authentication ###

      def presence(sid)
        get("/presence/#{sid}") { |err, result| yield err, result if block_given? }
      end

      def disconnect
        delete("/presence/#{sid}") { |err, result| yield err, result if block_given? }
      end

      ### Users - http://docs.ucengine.org/api.html#user ###

      def users
        get("/user") { |err, result| yield err, result if block_given? }
      end

      def user(uid)
        get("/user/#{uid}") { |err, result| yield err, result if block_given? }
      end

      def create_user(data)
        post("/user", data) { |err, result| yield err, result && result if block_given? }
      end

      def update_user(uid, data)
        put("/user/#{uid}", data) { |err, result| yield err, result if block_given? }
      end

      def delete_user(uid)
        delete("/user/#{uid}") { |err, result| yield err, result if block_given? }
      end

      ### General infos - http://docs.ucengine.org/api.html#infos ###

      def infos
        get("/infos") { |err, result| yield err, result if block_given? }
      end

      def update_infos(metadata)
        put("/infos", :metadata => metadata) { |err, result| yield err, result if block_given? }
      end

      ### Meetings - http://docs.ucengine.org/api.html#meeting ###

      def meetings(status=nil)
        get("/meeting/#{status}") { |err, result| yield err, result if block_given? }
      end

      def meeting(meeting)
        get("/meeting/all/#{meeting}") { |err, result| yield err, result if block_given? }
      end

      def create_meeting(meeting, body={})
        body.merge!(:name => meeting)
        post("/meeting/all", body) { |err, result| yield err, result if block_given? }
      end

      def update_meeting(meeting, body={})
        put("/meeting/all/#{meeting}", body) { |err, result| yield err, result if block_given? }
      end

      ### Rosters - http://docs.ucengine.org/api.html#join-a-meeting ###

      def roster(meeting)
        get("/meeting/all/#{meeting}/roster") { |err, result| yield err, result if block_given? }
      end

      def join_roster(meeting)
        post("/meeting/all/#{meeting}/roster") { |err, result| yield err, result if block_given? }
      end

      def quit_roster(meeting, uid=nil)
        delete("/meeting/all/#{meeting}/roster/#{uid || @uid}") { |err, result| yield err, result if block_given? }
      end

      ### Events - http://docs.ucengine.org/api.html#events ###

      def events(meeting, params={})
        params[:_async] = "no"
        get("/event/#{meeting}", params) { |err, result| yield err, result if block_given? }
      end

      def subscribe(meeting, params={}, &blk)
        params[:_async] = "lp"
        recurse = Proc.new do |err, result|
          next unless result
          blk.call(err, result)
          params[:start] = result.last["datetime"].to_i + 1
          get("/event/#{meeting}", params, &recurse) if EM.reactor_running?
        end
        time do |err, time|
          params[:start] = time
          get("/event/#{meeting}", params, &recurse)
        end
      end

      def publish(type, meeting=nil, metadata=nil)
        body = { :type => type }
        body[:metadata] = metadata if metadata
        post("/event/#{meeting}", body) { |err, result| yield err, result if block_given? }
      end

      def search(params)
        get("/search/event/", params) { |err, result| yield err, result if block_given? }
      end

      ### Files - http://docs.ucengine.org/api.html#upload-a-file ###

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
        # TODO: remove the 'new' after em-http-request@1.0.0beta3
        conn.use EventMachine::Middleware::JSONResponse.new
        req = conn.post( :head => {'content-type' => "multipart/form-data; boundary=#{body.boundary}"},
                         :body => body.to_s)
        req.errback  { yield HttpError.new(0, "connection error"), nil }
        req.callback do
          data = req.response
          if data['error']
            yield UCError.new(http.response_header.status, data["error"]), nil
          else
            yield nil, data['result']
          end
        end
      end

      ### Roles - http://docs.ucengine.org/api.html#roles ###

      def create_role(data)
        post("/role/", data) { |err, result| yield err, result if block_given? }
      end

      def delete_role(name)
        delete("/role/#{name}") { |err, result| yield err, result if block_given? }
      end

      def user_role(uid, params={})
        post("/user/#{uid}/roles", params){ |err, result| yield err, result if block_given? }
      end

    protected

      def get(path, params={})
        http_request(:get, path, :query => params) { |err, result| yield err, result }
      end

      def post(path, body=nil)
        http_request(:post, path, :body => body) { |err, result| yield err, result }
      end

      def put(path, body=nil)
        http_request(:put, path, :body => body) { |err, result| yield err, result }
      end

      def delete(path)
        http_request(:delete, path) { |err, result| yield err, result }
      end

      def http_request(method, path, opts={})
        key = (method == :get || method == :delete) ? :query : :body
        opts[key] ||= {}
        opts[key].merge!(:uid => uid, :sid => sid)

        conn = EM::HttpRequest.new(uce.url path)
        # TODO: remove the 'new' after em-http-request@1.0.0beta3
        conn.use EventMachine::Middleware::JSONResponse.new
        req = conn.send(method, opts)
        req.errback  { yield HttpError.new(0, "connect error"), nil }
        req.callback do
          data = req.response
          if data['error']
            yield UCError.new(req.response_header.status, data["error"]), nil
          else
            result = data["result"]
            yield nil, result
          end
        end
      end
    end
  end
end
