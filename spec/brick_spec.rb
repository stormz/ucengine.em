#!/usr/bin/env ruby

require "minitest/autorun"
require "em-spec/test"

require "em-ucengine"
require "em-ucengine/brick"
require "em-ucengine/brick_test"

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

describe EM::UCEngine::Brick::Test do
  include EM::UCEngine::Brick::Test
  include EventMachine::Test

  class MyBrick2
    include EM::UCEngine::Brick

    attr_accessor :cpt

    bootstrap do
      @cpt = 0
    end

    on "incr" do |event|
      @cpt += 1
    end

    on "ping" do |event|
      uce.publish("pong", "meeting")
    end
  end

  def app
    MyBrick2
  end

  it "allows to test bricks" do
    brick.cpt.must_equal 0
    trigger "incr"
    brick.cpt.must_equal 1
    done
  end

  it "allows to test ucengine calls" do
    brick.uce.expect(:publish, nil, ["pong", "meeting"])
    trigger "ping"
    brick.uce.verify
    done
  end
end
