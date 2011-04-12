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

  it "fetches /time from UCEngine" do
    EM.run do
      uce = EventMachine::UCEngine.new
      uce.time do |time|
        time.wont_be_nil
        EM.stop
      end
    end
  end

  it "is possible to authenticate a user" do
    with_authentication do |sess|
      sess.wont_be_nil
      sess.uce.must_be_instance_of EventMachine::UCEngine
      sess.uid.wont_be_nil
      sess.sid.wont_be_nil
      EM.stop
    end
  end

end
