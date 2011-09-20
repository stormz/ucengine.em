#!/usr/bin/env ruby

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

require "em-ucengine"
require "eventmachine"

#
# You can use eventmachine helpers.
# Here, we ask 1500 times for hours, whith 10 connections, and waiting for a global responses.
# It could be more clever to create users with such tools, not asking hour.
#

EventMachine::UCEngine::Client.run do |uce|
  EM::Iterator.new(1..1500, 10).map(proc { |i, iter|
    uce.time {|error, value| iter.return value }
  }, proc{|responses|
    puts responses.inspect
    EM.stop
  })
end
