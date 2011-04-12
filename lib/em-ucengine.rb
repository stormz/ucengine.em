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
      http = EM::HttpRequest.new(url "time").get
      http.errback  { yield nil }
      http.callback do
        data = Yajl::Parser.parse(http.response)
        yield data && data.has_key?("result") && data["result"].to_i
      end
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
        uce.time { |time| yield time }
      end

      def presence(sid)
        get("/presence/#{sid}") { |infos| yield infos }
      end

    protected

      def query
        { :uid => uid, :sid => sid }
      end

      def get(path)
        http = EM::HttpRequest.new(uce.url path).get(:query => query)
        http.errback  { yield nil }
        http.callback do
          data = Yajl::Parser.parse(http.response)
          yield data && data.has_key?("result") && data["result"]
        end
      end
    end
  end
end
