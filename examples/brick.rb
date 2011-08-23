#!/usr/bin/env ruby

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

require "em-ucengine"
require "em-ucengine/brick"

class Brick1
  include EM::UCEngine::Brick

  bootstrap do
    every 1.sec do
      @uce.publish "em-ucengine.example.ping"
    end
  end

  on "em-ucengine.example.ping" do |event|
    puts "PING: #{event.inspect}"
    @uce.publish "em-ucengine.example.pong"
  end
end

class Brick2
  include EM::UCEngine::Brick

  on "em-ucengine.example.pong" do |event|
    puts "PONG: #{event.inspect}"
  end
end

class MetaBrick
  include EM::UCEngine::Brick

  use Brick1
  use Brick2
end

# v1
EM.run do
  brick = MetaBrick.new( :host => "localhost", :port => 5280,
                         :name => "root", :credential => "root" )

  brick.start
end
