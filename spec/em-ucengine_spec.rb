#!/usr/bin/env ruby

require "minitest/autorun"
require "em-ucengine"


# See http://docs.ucengine.org/install.html#inject-some-data
USER = "root"
PASS = "root"
CHAN = "demo"


describe EventMachine::UCEngine do
  def with_authentication
    EventMachine::UCEngine.run do |uce|
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

  it "lists users" do
    with_authentication do |s|
      s.users do |users|
        users.must_be_instance_of Array
        users.count.must_be :>=, 1
        users.map {|u| u["name"] }.must_include USER
        EM.stop
      end
    end
  end

  it "find a user with its uid" do
    with_authentication do |s|
      s.user(s["uid"]) do |user|
        user.wont_be_nil
        user["name"].must_equal USER
        EM.stop
      end
    end
  end

  it "create a user and delete it" do
    with_authentication do |s|
      s.create_user(:name => "John Doe #{rand 10_000}", :auth => "password", :credential => "foobar", :metadata => {}) do |user_id|
        user_id.wont_be_nil
        user_id.size.must_be :>, 0
        s.delete_user(user_id)
        EM.stop
      end
    end
  end

  it "get current domain informations" do
    with_authentication do |s|
      s.infos do |infos|
        infos.wont_be_nil
        infos["domain"].must_equal "localhost"
        EM.stop
      end
    end
  end

  it "publish an event and retrieves it" do
    with_authentication do |s|
      n = rand(1_000_000_000)
      s.publish("em-ucengine.spec.publish", CHAN, :number => n) do
        s.events(CHAN, :type => "em-ucengine.spec.publish", :count => 1, :order => 'desc') do |events|
          events.wont_be_nil
          events.first["metadata"]["number"].to_i.must_equal n
          EM.stop
        end
      end
    end
  end

  it "subscribe to events" do
    with_authentication do |s|
      numbers = (0..2).map { rand(1_000_000_000) }

      numbers.each.with_index do |n,i|
        EM.add_timer(0.2 * i) { s.publish("em-ucengine.spec.subscribe", CHAN, :number => n) }
      end

      s.subscribe(CHAN, :type => "em-ucengine.spec.subscribe") do |events|
        n = events.first["metadata"]["number"].to_i
        numbers.must_include n
        numbers.delete(n)
        EM.stop if numbers.empty?
      end
    end
  end

  it "create a role and delete it" do
    role_name = "Role #{rand 10_000}"
    with_authentication do |s|
      s.create_role(:name => role_name, :auth => "password", :credential => "foobar", :metadata => {}) do |result|
        result.wont_be_nil
        result.must_be :==, 'created'
        s.delete_role(role_name)
        EM.stop
      end
    end
  end

  it "set user role" do
    role_name = "role#{rand 10_000}"
    with_authentication do |s|
      s.create_role(:name => role_name, :auth => "password", :credential => "foobar", :metadata => {}) do |r|
        s.user_role(s.uid, :role => role_name, :auth => "password", :credential => "foobar") do |result|
          result.wont_be_nil
          result.must_be :==, 'ok'
          s.delete_role(role_name)
          EM.stop
        end
      end
    end
  end

  it "create a meeting and delete it" do
    with_authentication do |s|
      n = rand(99999).to_s
      s.create_meeting("chuck_#{n}") do |result|
        result.must_be :==, 'created'
        EM.stop
      end
    end
  end

  it "upload a file in a meeting" do
    with_authentication do |s|
      s.upload("demo", File.new(__FILE__), { :chuck => 'norris' }) do |result|
        result.must_include File.basename(__FILE__, '.rb')
        EM.stop
      end
    end
  end

end
