#!/usr/bin/env ruby

require "minitest/autorun"
require "em-ucengine"


# See http://docs.ucengine.org/install.html#inject-some-data
USER = "root"
PASS = "root"
CHAN = "demo"

describe UCEngine::Client do
  describe UCEngine::Client do

    def with_authentication
      uce = UCEngine::Client.new
      session = uce.connect(USER, PASS)
      session.must_be_instance_of UCEngine::Client::Session
      yield session
    end

    it "fetches /time from UCEngine, no auth required" do
      uce = UCEngine::Client.new
      time = uce.time
      time.wont_be_nil
    end

    it "is possible to authenticate a user" do
      with_authentication do |session|
        session.wont_be_nil
        session.uce.must_be_instance_of UCEngine::Client
        session.uid.wont_be_nil
        session.sid.wont_be_nil
      end
    end

    it "fails when trying to authenticate a non existant user" do
      uce = UCEngine::Client.new
      proc do
        session = uce.connect("Nobody", "pwd")
      end.must_raise UCEngine::Client::UCError
    end

    it "fetches time, with auth" do
      with_authentication do |s|
        time = s.time
        time.wont_be_nil
      end
    end

    it "retrieves presence informations" do
      with_authentication do |s|
        infos = s.presence(s.sid)
        infos.wont_be_nil
        infos["user"].must_equal s["uid"]
      end
    end
  end
end
