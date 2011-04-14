#!/usr/bin/env ruby

require "em-ucengine"

EventMachine::UCEngine.run do |uce|
  uce.connect("participant", "pwd") do |session|
    EM.add_periodic_timer(1) { session.publish("em-ucengine.example.ping", "demo") }
    session.subscribe("demo") do |event|
      puts "Hey, we received an event: #{event.inspect}"
    end
  end
end
