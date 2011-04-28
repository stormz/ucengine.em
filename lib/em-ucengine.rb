require "eventmachine"
require "em-http-request"
require "yajl"


module EventMachine
  class UCEngine

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
      Session.new(self, nil, nil).time { |time| yield time }
    end

    def connect(user, password, metadata=nil)
      body = { "name" => user, "credential" => password }
      body["metadata"] = metadata if metadata
      http = EM::HttpRequest.new(url "/presence").post :body => body
      http.errback  { yield nil }
      http.callback do
        data = Yajl::Parser.parse(http.response)
        data = data["result"] if data
        yield Session.new(self, data["uid"], data["sid"])
      end
    end

    def url(path)
      "http://#{@host}:#{@port}#{@root}/#{@version}#{path}"
    end

    class Session < Struct.new(:uce, :uid, :sid)

      ### Time - http://docs.ucengine.org/api.html#time ###

      def time
        get("/time") { |result| yield result if block_given? }
      end

      ### Presence - http://docs.ucengine.org/api.html#authentication ###

      def presence(sid)
        get("/presence/#{sid}") { |result| yield result if block_given? }
      end

      def disconnect
        delete("/presence/#{sid}") { |result| yield result if block_given? }
      end

      ### Users - http://docs.ucengine.org/api.html#user ###

      def users
        get("/user") { |result| yield result if block_given? }
      end

      def user(uid)
        get("/user/#{uid}") { |result| yield result if block_given? }
      end

      def create_user(data)
        post("/user", data) { |result| yield result && result if block_given? }
      end

      def update_user(uid, data)
        put("/user/#{uid}", data) { |result| yield result if block_given? }
      end

      def delete_user(uid)
        delete("/user/#{uid}") { |result| yield result if block_given? }
      end

      ### General infos - http://docs.ucengine.org/api.html#infos ###

      def infos
        get("/infos") { |result| yield result if block_given? }
      end

      def update_infos(metadata)
        put("/infos", :metadata => metadata) { |result| yield result if block_given? }
      end

      ### Meetings - http://docs.ucengine.org/api.html#meeting ###

      def meetings(status=nil)
        get("/meeting/#{status}") { |result| yield result if block_given? }
      end

      def meeting(meeting)
        get("/meeting/all/#{meeting}") { |result| yield result if block_given? }
      end

      def create_meeting(meeting, body={})
        body.merge!(:name => meeting)
        post("/meeting/all", body) { |result| yield result if block_given? }
      end

      def update_meeting(meeting, body={})
        put("/meeting/all/#{meeting}", body) { |result| yield result if block_given? }
      end

      def delete_meeting(meeting)
        delete("/meeting/all/#{meeting}") { |result| yield result if block_given? }
      end

      ### Rosters - http://docs.ucengine.org/api.html#join-a-meeting ###

      def roster(meeting)
        get("/meeting/all/#{meeting}/roster") { |result| yield result if block_given? }
      end

      def join_roster(meeting)
        post("/meeting/all/#{meeting}/roster") { |result| yield result if block_given? }
      end

      def quit_roster(meeting, uid=nil)
        delete("/meeting/all/#{meeting}/roster/#{uid || @uid}") { |result| yield result if block_given? }
      end

      ### Events - http://docs.ucengine.org/api.html#events ###

      def events(meeting, params={})
        params[:_async] = "no"
        get("/event/#{meeting}", params) { |result| yield result if block_given? }
      end

      def subscribe(meeting, params={}, &blk)
        params[:_async] = "lp"
        recurse = Proc.new do |result|
          next unless result
          blk.call(result)
          params[:start] = result.last["datetime"].to_i + 1
          get("/event/#{meeting}", params, &recurse) if EM.reactor_running?
        end
        time do |time|
          params[:start] = time
          get("/event/#{meeting}", params, &recurse)
        end
      end

      def publish(type, meeting=nil, metadata=nil)
        body = { :type => type }
        body[:metadata] = metadata if metadata
        post("/event/#{meeting}", body) { |result| yield result if block_given? }
      end

      def search(params)
        get("/search/event/", params) { |result| yield result if block_given? }
      end

      ### Roles - http://docs.ucengine.org/api.html#roles ###

      def create_role(data)
        post("/role/", data) { |result| yield result if block_given? }
      end

      def delete_role(name)
        delete("/role/#{name}") { |result| yield result if block_given? }
      end

      def user_role(uid, params={})
        post("/user/#{uid}/roles", params){ |result| yield result if block_given? }
      end

    protected

      def get(path, params={})
        http_request(:get, path, :query => params) { |result| yield result }
      end

      def post(path, body=nil)
        http_request(:post, path, :body => body) { |result| yield result }
      end

      def put(path, body=nil)
        http_request(:put, path, :body => body) { |result| yield result }
      end

      def delete(path)
        http_request(:delete, path) { |result| yield result }
      end

      def http_request(method, path, opts={})
        opts[:query] ||= {}
        opts[:query].merge!(:uid => uid, :sid => sid)
        http = EM::HttpRequest.new(uce.url path).send(method, opts)
        http.errback  { yield nil }
        http.callback do
          data = Yajl::Parser.parse(http.response)
          yield data && data.has_key?("result") && data["result"]
        end
      end
    end
  end
end
