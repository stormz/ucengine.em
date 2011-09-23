require 'net/http'
require 'json'
require 'cgi'

require_relative "errors"

module UCEngine
  module NetHttpResponse

    def answer(req)
      if req.kind_of?(Net::HTTPServerError)
        raise UCEngine::Client::HttpError.new(req.code, req.body)
      end

      data = JSON.parse(req.body)
      if data['error']
        raise UCEngine::Client::UCError.new(req.code, data['error'])
      end

      data['result']
    end

    def answer_bool(req, &block)
      result = answer(req)
      result == "true"
    end

    def answer_connect(req)
      credentials = answer(req)
      UCEngine::Client::Session.new(self, credentials['uid'], credentials['sid'])
    end

  end

  module NetHttpRequest

    def get(path, params=nil)
      uri = URI.parse(path)
      params ||= {}
      params.merge!({:uid => self.uid, :sid => self.sid})

      query = params.collect { |k,v| "#{k}=#{CGI::escape(v.to_s)}" }.join('&') if params
      Net::HTTP.start(uri.host, uri.port) do |http|
        http.get("#{uri.path}?#{query}")
      end
    end

    def post(path, params=nil, body=nil)
      uri = URI.parse(path)
      body ||={}
      body.merge!(params) if params
      body.merge!({:uid => self.uid, :sid => self.sid}) if self.class == UCEngine::Client::Session

      Net::HTTP.post_form(uri, body)
    end

    def delete(path, params=nil)
      uri = URI.parse(path)
      params ||= {}
      params.merge!({:uid => self.uid, :sid => self.sid})

      query = params.collect { |k,v| "#{k}=#{CGI::escape(v.to_s)}" }.join('&') if params
      Net::HTTP.start(uri.host, uri.port) do |http|
        http.delete("#{uri.path}?#{query}")
      end
    end

    # Perform a post request on the API with a content type application/json
    #
    # @param [String] path
    # @param [Hash] body
    def json_post(path, body)
      #http_request(:post, path, {}, body, nil, {'Content-Type' => 'application/json'})
      uri = URI.parse(path)

      req = Net::HTTP::Post.new(uri.path)
      req.body = body.to_json
      req.add_field("Content-Type", "application/json")

      Net::HTTP.new(uri.host, uri.port).start do |http|
        http.request(req)
      end
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

