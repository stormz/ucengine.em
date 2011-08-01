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
      uce.connect(USER, PASS) { |err, sess|
        if err
          EM.stop
          raise err
        end
        yield sess
      }
    end
  end

  it "fetches /time from UCEngine, no auth required" do
    EM.run do
      uce = EventMachine::UCEngine.new
      uce.time do |err, time|
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

  it "fails when trying to authenticate a non existant user" do
    EM.run do
      EventMachine::UCEngine.run do |uce|
        uce.connect('Nobody', 'pwd') { |err, sess|
          err.wont_be_nil
          err.code.must_equal 404
          EM.stop
        }
      end
    end
  end

  it "fetches time" do
    with_authentication do |s|
      s.time do |err, time|
        time.wont_be_nil
        EM.stop
      end
    end
  end

  it "retrieves presence informations" do
    with_authentication do |s|
      s.presence(s.sid) do |err, infos|
        infos.wont_be_nil
        infos["user"].must_equal s["uid"]
        EM.stop
      end
    end
  end

  it "lists users" do
    with_authentication do |s|
      s.users do |err, users|
        users.must_be_instance_of Array
        users.count.must_be :>=, 1
        users.map {|u| u["name"] }.must_include USER
        EM.stop
      end
    end
  end

  it "find a user with its uid" do
    with_authentication do |s|
      s.user(s["uid"]) do |err, user|
        user.wont_be_nil
        user["name"].must_equal USER
        EM.stop
      end
    end
  end

  it "create a user and delete it" do
    with_authentication do |s|
      s.create_user(:name => "John Doe #{rand 10_000}", :auth => "password", :credential => "foobar", :metadata => {}) do |err, user_id|
        user_id.wont_be_nil
        user_id.size.must_be :>, 0
        s.delete_user(user_id)
        EM.stop
      end
    end
  end

  it "get current domain informations" do
    with_authentication do |s|
      s.infos do |err, infos|
        assert_nil err
        infos.wont_be_nil
        infos["domain"].must_equal "localhost"
        EM.stop
      end
    end
  end

  it "publish an event and retrieves it" do
    with_authentication do |s|
      n = rand(1_000_000_000)
      s.publish("em-ucengine.spec.publish", CHAN, :number => n) do |err, event_id|
        err.must_be_nil
        event_id.wont_be_nil
        s.events(CHAN, :type => "em-ucengine.spec.publish", :count => 1, :order => 'desc') do |err, events|
          events.wont_be_nil
          events.first["metadata"]["number"].to_i.must_equal n

          s.event(event_id) do |err, event|
            err.must_be_nil
            event.wont_be_nil
            event['id'].must_equal event_id

            EM.stop
          end
        end
      end
    end
  end

  it "subscribe to events" do
    with_authentication do |s|
      numbers = (0..2).map { rand(1_000_000_000) }

      numbers.each.with_index do |n,i|
        EM.add_timer(0.2 * i) do
          s.publish("em-ucengine.spec.subscribe", CHAN, :number => n) do |err, result|
            assert_nil err
            result.wont_be_nil
          end
        end
      end

      subscription = s.subscribe(CHAN, :type => "em-ucengine.spec.subscribe") do |err, events|
        assert_nil err
        events.wont_be_nil

        events.each do |event|
          n = numbers.shift
          event["metadata"]["number"].to_i.must_equal n
        end

        subscription.cancel { EM.stop } if numbers.empty?
      end
    end
  end

  it "create a role and delete it" do
    role_name = "Role #{rand 10_000}"
    with_authentication do |s|
      s.create_role(:name => role_name, :auth => "password", :credential => "foobar", :metadata => {}) do |err, result|
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
      s.create_role(:name => role_name, :auth => "password", :credential => "foobar", :metadata => {}) do |err, r|
        r.wont_be_nil
        s.user_role(s.uid, :role => role_name, :auth => "password", :credential => "foobar") do |err, result|
          result.wont_be_nil
          result.must_be :==, 'ok'
          s.user_can(s.uid, "update", "meeting") do |err, result|
            err.must_be_nil
            result.must_be :==, true
            s.delete_role(role_name)
            EM.stop
          end
        end
      end
    end
  end

  it "create a meeting and delete it" do
    with_authentication do |s|
      n = rand(99999).to_s
      s.create_meeting("chuck_#{n}") do |err, result|
        result.must_be :==, 'created'
        EM.stop
      end
    end
  end

  it "upload and download a file in a meeting" do
    with_authentication do |s|
      file = File.new(__FILE__)
      content = File.read(__FILE__)
      s.upload(CHAN, file, { :chuck => 'norris' }) do |err, result|
        assert_nil err
        result.wont_be_nil
        s.download(CHAN, result) do |err, file2|
          assert_nil err
          file2.open.read.must_be :==, content
          file2.close
          file.close
          EM.stop
        end
      end
    end
  end

  it "list files and delete" do
    with_authentication do |s|
      file = File.new(__FILE__)
      s.upload(CHAN, file, { :chuck => 'norris' }) do |err, filename|
        assert_nil err
        s.files(CHAN) do |err, result|
          assert_nil err
          result.size.must_be :>, 0
          s.delete_file(CHAN, filename) do |err, result|
            assert_nil err
            result.must_be :==, "ok"

            EM.stop
          end
        end
      end
    end
  end
end
