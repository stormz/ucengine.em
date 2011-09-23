#!/usr/bin/env ruby

require "minitest/autorun"
require "em-ucengine"

# See http://docs.ucengine.org/install.html#inject-some-data
USER = "root"
PASS = "root"
CHAN = "demo"

describe UCEngine::Client do
  def with_authentication
    uce = UCEngine::Client.new
    session = uce.connect(USER, PASS)
    session.must_be_instance_of UCEngine::Client::Session
    yield session
  end

  def with_random_user
    with_authentication do |s|
      user_id = s.create_user(:name => "John Doe #{rand 10_000}", :auth => "password", :credential => "foobar")
      yield s, user_id
    end
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

  it "lists users" do
    with_authentication do |s|
      users = s.users
      users.must_be_instance_of Array
      users.count.must_be :>=, 1
      users.map {|u| u["name"] }.must_include USER
    end
  end

  it "find a user with its uid" do
    with_authentication do |s|
      user = s.user(s["uid"])
      user.wont_be_nil
      user["name"].must_equal USER
    end
  end

  it "creates a user and delete it" do
    with_authentication do |s|
      user_id = s.create_user(:name => "John Doe #{rand 10_000}", :auth => "password", :credential => "foobar")
      user_id.wont_be_nil
      user_id.size.must_be :>, 0
      result = s.delete_user(user_id)
      result.wont_be_nil
    end
  end

  it "get current domain informations" do
    with_authentication do |s|
      infos = s.infos
      infos.wont_be_nil
      infos["domain"].must_equal "localhost"
    end
  end

  it "publish an event and retrieves it" do
    with_authentication do |s|
      n = rand(1_000_000_000)
      event_id = s.publish("em-ucengine.spec.publish", CHAN, :number => n)
      event_id.wont_be_nil

      events = s.events(CHAN, :type => "em-ucengine.spec.publish", :count => 1, :order => 'desc')
      events.wont_be_nil "events"
      events.first["metadata"]["number"].to_i.must_equal n

      event = s.event(event_id)
      event.wont_be_nil "event"
      event['id'].must_equal event_id
    end
  end

  it "create a role and delete it" do
    role_name = "Role_#{rand 10_000}"
    with_authentication do |s|
      result = s.create_role(:name => role_name, :auth => "password", :credential => "foobar", :metadata => {})
      result.wont_be_nil
      result.must_be :==, 'created'

      result = s.delete_role(role_name)
      result.wont_be_nil
    end
  end

  it "set user role" do
    role_name = "role#{rand 10_000}"
    with_random_user do |s, user_id|
      result = s.create_role(:name => role_name, :auth => "password", :credential => "foobar", :metadata => {})
      result.wont_be_nil

      result = s.user_role(user_id, :role => role_name)
      result.must_equal 'ok'

      result = s.user_can(s.uid, "update", "meeting")
      result.must_equal true

      s.delete_role(role_name)
    end
  end

  it "create a meeting" do
    with_authentication do |s|
      n = rand(99999).to_s
      result = s.create_meeting("chuck_#{n}")
      result.must_be :==, 'created'
    end
  end
end
