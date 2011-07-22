#!/usr/bin/env ruby

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

require "em-ucengine"

EventMachine::UCEngine.run do |uce|
  uce.connect("participant", "pwd") do |error, session|
    EM.add_periodic_timer(1) do
        session.publish("em-ucengine.example.ping", "demo", {:type => "something", :value => [1,2,3]}) 
    end
    session.subscribe("demo") do |event|
      puts "Hey, we received an event: #{event.inspect}"
    end
  end
end
