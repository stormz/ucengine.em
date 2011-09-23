#!/usr/bin/env ruby

require "minitest/autorun"
require "em-ucengine"
require "em-ucengine/client_em"
require "em-ucengine/brick"

describe EventMachine::UCEngine::Brick do
  it "can contruct a new brick" do
    class MyBrick
      include EM::UCEngine::Brick

      on "ping" do |event|
      end
    end
    brick = MyBrick.new
    brick.routes["ping"].size.must_equal 1
  end
end
