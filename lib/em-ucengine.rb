require "eventmachine"
require "em-http-request"
require "yajl"


module EventMachine
  class UCEngine

    def initialize(host="localhost", port=5280, api_root="/api", api_version="0.4")
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
      http = EM::HttpRequest.new(url "presence").post :body => body
      http.errback  { yield nil }
      http.callback do
        data = Yajl::Parser.parse(http.response)
        data = data["result"] if data
        yield Session.new(self, data["uid"], data["sid"])
      end
    end

    def url(path)
      "http://#{@host}:#{@port}#{@root}/#{@version}/#{path}"
    end

    class Session < Struct.new(:uce, :uid, :sid)
      def time
        get("/time") { |result| yield result }
      end

      def presence(sid)
        get("/presence/#{sid}") { |result| yield result }
      end

      def disconnect
        delete("/presence/#{sid}") { }
      end

      def users
        get("/user") { |result| yield result }
      end

      def user(uid)
        get("/user/#{uid}") { |result| yield result }
      end

      def create_user(data)
        post("/user", data) { |result| yield result && result.to_i }
      end

      def update_user(uid, data)
        put("/user/#{uid}", data) { |result| yield result }
      end

      def delete_user(uid)
        delete("/user/#{uid}") { }
      end

      def infos
        get("/infos") { |result| yield result }
      end

      def update_infos(metadata)
        put("/infos", :metadata => metadata) { |result| yield result }
      end

    protected

      def get(path)
        http_request(:get, path) { |result| yield result }
      end

      def post(path, body=nil)
        http_request(:post, path, body) { |result| yield result }
      end

      def put(path, body=nil)
        http_request(:put, path, body) { |result| yield result }
      end

      def delete(path)
        http_request(:delete, path) { |result| yield result }
      end

      def http_request(method, path, body=nil)
        opts = { :query => { :uid => uid, :sid => sid } }
        opts[:body] = body if body
        http = EM::HttpRequest.new(uce.url path).send(method, opts)
        http.errback  { yield nil }
        http.callback do
          data = Yajl::Parser.parse(http.response)
          $stderr.puts ">> #{method} #{path}: #{data.inspect}"
          yield data && data.has_key?("result") && data["result"]
        end
      end
    end
  end
end
