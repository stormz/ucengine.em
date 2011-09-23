#!/usr/bin/env ruby

require "minitest/autorun"
require "em-ucengine"

# See http://docs.ucengine.org/install.html#inject-some-data
USER = "root"
PASS = "root"
CHAN = "demo"

describe EM::UCEngine do
  describe EM::UCEngine::Client do

    def with_authentication
      EM::UCEngine::Client.run do |uce|
        uce.connect(USER, PASS) { |err, sess|
          err.must_be_nil
          sess.wont_be_nil
          sess.uid.wont_be_nil
          sess.sid.wont_be_nil
          if err
            EM.stop
            raise err
          end
          yield sess
        }
      end
    end

    def with_random_user
      with_authentication do |s|
        s.create_user(:name => "John Doe #{rand 10_000}", :auth => "password", :credential => "foobar") do |err, user_id|
          yield s, user_id
        end
      end
    end

    it "fetches /time from UCEngine, no auth required" do
      EM.run do
        uce = EM::UCEngine::Client.new
        uce.time do |err, time|
          err.must_be_nil
          time.wont_be_nil
          EM.stop
        end
      end
    end

    it "is possible to authenticate a user" do
      with_authentication do |session|
        session.wont_be_nil
        session.uce.must_be_instance_of EM::UCEngine::Client
        session.uid.wont_be_nil
        session.sid.wont_be_nil
        EM.stop
      end
    end

    it "fails when trying to authenticate a non existant user" do
      EM::UCEngine::Client.run do |uce|
        uce.connect('Nobody', 'pwd') do |err, sess|
          err.wont_be_nil
          err.code.must_equal 404
          EM.stop
        end
      end
    end

    it "is possible to authenticate with a deferrable" do
      EM.run do
        uce = EM::UCEngine::Client.new
        req = uce.connect(USER, PASS)
        req.must_be_instance_of EM::DefaultDeferrable
        req.callback do |session|
          session.must_be_instance_of EM::UCEngine::Client::Session
          EM.stop
        end
        req.errback do |err|
          assert false, "must not be called"
          EM.stop
        end
      end
    end

    it "return a deferrable and call the success callback" do
      EM.run do
        uce = EM::UCEngine::Client.new
        req = uce.time
        req.must_be_instance_of EM::DefaultDeferrable
        req.callback do |time|
          time.wont_be_nil
          EM.stop
        end
        req.errback do |err|
          assert false, "must not be called"
          EM.stop
        end
      end
    end

    it "return a deferrable and call the error callback" do
      with_authentication do |s|
        req = s.answer(s.get(s.url('/404')))
        req.must_be_instance_of EM::DefaultDeferrable
        req.callback do |time|
          assert false, "must not be called"
          EM.stop
        end
        req.errback do |err|
          err.wont_be_nil
          EM.stop
        end
      end
    end

    it "fetches time, with auth" do
      with_authentication do |s|
        s.time do |err, time|
          err.must_be_nil
          time.wont_be_nil
          EM.stop
        end
      end
    end

    it "retrieves presence informations" do
      with_authentication do |s|
        s.presence(s.sid) do |err, infos|
          err.must_be_nil
          infos.wont_be_nil
          infos["user"].must_equal s["uid"]
          EM.stop
        end
      end
    end

    it "lists users" do
      with_authentication do |s|
        s.users do |err, users|
          err.must_be_nil
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
          err.must_be_nil
          user.wont_be_nil
          user["name"].must_equal USER
          EM.stop
        end
      end
    end

    it "create a user and delete it" do
      with_authentication do |s|
        s.create_user(:name => "John Doe #{rand 10_000}", :auth => "password", :credential => "foobar") do |err, user_id|
          err.must_be_nil
          user_id.wont_be_nil
          user_id.size.must_be :>, 0
          s.delete_user(user_id) do |err, result|
            err.must_be_nil
            result.wont_be_nil
            EM.stop
          end
        end
      end
    end

    it "get current domain informations" do
      with_authentication do |s|
        s.infos do |err, infos|
          err.must_be_nil
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
            events.wont_be_nil "events"
            events.first["metadata"]["number"].to_i.must_equal n

            s.event(event_id) do |err, event|
              err.must_be_nil
              event.wont_be_nil "event"
              event['id'].must_equal event_id

              EM.stop
            end
          end
        end
      end
    end

    it "subscribe to events" do
      numbers = (0..2).map { rand(1_000_000_000) }
      with_authentication do |s|
        subscription = s.subscribe(CHAN, :type => "em-ucengine.spec.subscribe") do |err, events|
          err.must_be_nil
          events.wont_be_nil

          events.each do |event|
            n = numbers.shift
            event["metadata"]["number"].to_i.must_equal n
          end
          subscription.cancel { EM.stop } if numbers.empty?
        end
        numbers.each.with_index do |n,i|
          EM.add_timer(0.2 * i) do
            s.publish("em-ucengine.spec.subscribe", CHAN, :number => n) do |err, result|
              assert_nil err
              result.wont_be_nil
            end
          end
        end
      end
    end

    it "create a role and delete it" do
      role_name = "Role_#{rand 10_000}"
      with_authentication do |s|
        s.create_role(:name => role_name, :auth => "password", :credential => "foobar", :metadata => {}) do |err, result|
          err.must_be_nil
          result.wont_be_nil
          result.must_be :==, 'created'
          s.delete_role(role_name) do |err, result|
            err.must_be_nil
            EM.stop
          end
        end
      end
    end

    it "set user role" do
      role_name = "role#{rand 10_000}"
      with_random_user do |s, user_id|
        s.create_role(:name => role_name, :auth => "password", :credential => "foobar", :metadata => {}) do |err, r|
          err.must_be_nil
          r.wont_be_nil
          s.user_role(user_id, :role => role_name) do |err, result|
            err.must_be_nil
            result.must_equal 'ok'
            s.user_can(s.uid, "update", "meeting") do |err, result|
              err.must_be_nil
              result.must_equal true
              s.delete_role(role_name)
              EM.stop
            end
          end
        end
      end
    end

    it "create a meeting" do
      with_authentication do |s|
        n = rand(99999).to_s
        s.create_meeting("chuck_#{n}") do |err, result|
          err.must_be_nil
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
          err.must_be_nil
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
          err.must_be_nil
          s.files(CHAN) do |err, result|
            err.must_be_nil
            result.size.must_be :>, 0
            s.delete_file(CHAN, filename) do |err, result|
              err.must_be_nil
              result.must_be :==, "ok"

              EM.stop
            end
          end
        end
      end
    end
  end
end
