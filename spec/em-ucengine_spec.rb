#!/usr/bin/env ruby

require "minitest/autorun"
require "em-ucengine"


# See http://docs.ucengine.org/install.html#inject-some-data
USER = "participant"
PASS = "pwd"


describe EventMachine::UCEngine do
  def with_authentication
    EM.run do
      uce = EventMachine::UCEngine.new
      uce.connect(USER, PASS) { |sess| yield sess }
    end
  end

  it "fetches /time from UCEngine, no auth required" do
    EM.run do
      uce = EventMachine::UCEngine.new
      uce.time do |time|
        time.wont_be_nil
        EM.stop
      end
    end
  end

  it "is possible to authenticate a user" do
    with_authentication do |session|
      session.wont_be_nil
      session.uce.must_be_instance_of EventMachine::UCEngine
      session.uid.wont_be_nil
      session.sid.wont_be_nil
      EM.stop
    end
  end

  it "fetches time" do
    with_authentication do |s|
      s.time do |time|
        time.wont_be_nil
        EM.stop
      end
    end
  end

  it "retrieves presence informations" do
    with_authentication do |s|
      s.presence(s.sid) do |infos|
        infos.wont_be_nil
        infos["user"].must_equal s["uid"]
        EM.stop
      end
    end
  end

end
