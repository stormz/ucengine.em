require 'net/http'
require 'json'
require 'cgi'

require_relative "errors"

module UCEngine
  module NetHttpResponse

    def answer(req)
      if req.kind_of?(Net::HTTPServerError)
        raise UCEngine::Client::HTTPError.new(req.code, req.body)
      end

      data = JSON.parse(req.body)
      if data['error']
        raise UCEngine::Client::UCError.new(req.code, data['error'])
      end

      data['result']
    end

    def answer_connect(req)
      credentials = answer(req)
      UCEngine::Client::Session.new(self, credentials['uid'], credentials['sid'])
    end

    alias :answer_download :answer
  end

  module NetHttpRequest
    def get(path, params={}, session=nil)
      uri = URI.parse(path)
      params.merge!(:uid => self.uid, :sid => self.sid) if self.class == UCEngine::Client::Session
      query = params.collect { |k,v| "#{k}=#{CGI::escape(v.to_s)}" }.join('&') if params
      Net::HTTP.start(uri.host, uri.port) do |http|
        http.get("#{uri.path}?#{query}")
      end
    end

    def post(path, params=nil, body=nil, session=nil)
      uri = URI.parse(path)
      Net::HTTP.post_form(uri, body)
    end

    def put(path, params=nil, body=nil, session=nil)
    end

  end

  class Client
    include UCEngine::NetHttpResponse
    include UCEngine::NetHttpRequest

    class Session
      include UCEngine::NetHttpResponse
      include UCEngine::NetHttpRequest
    end
  end
end

