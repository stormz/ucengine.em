# EventMachine library for U.C.Engine

em-ucengine is a Ruby library for [U.C.Engine](http://ucengine.org/) powered
by [EventMachine](https://github.com/eventmachine/eventmachine). It can
connect, subscribe and publish events to U.C.Engine.

## Install

Install with Rubygems:

    gem install em-ucengine

If you use bundler, add it to your `Gemfile`:

    gem "em-ucengine", "~>0.2"

## Usage

### Client

#### EventMachine

We have a classic block style API:

```ruby
require "em-ucengine"
EventMachine::UCEngine::Client.run do |uce|
  uce.connect("participant", "pwd") do |err, session|
    EM.add_periodic_timer(1) { session.publish("em-ucengine.example.ping", "demo") }
    session.subscribe("demo") do |err, event|
      puts "Hey, we received an event: #{event.inspect}"
    end
  end
end
```

Each method call return a deferable.

```ruby
require "em-ucengine"
EventMachine::UCEngine::Client.run do |uce|
  req = uce.connect("participant", "pwd")
  req.callback do |session|
    session.publish("em-ucengine.example.ping", "demo")
  end
  req.errback do |error|
     puts "error"
  end
end
```

#### Net/HTTP

```ruby
require "em-ucengine"

uce = UCEngine::Client.new
session = uce.connect("participant", "pwd")
session.publish("em-ucengine.example.ping", "demo")
```

### Brick

```ruby
require "em-ucengine"
require "em-ucengine/brick"

class MyBrick
  include EM::UCEngine::Brick

  on "ping" do |event|
    puts event
  end
end

brick = MyBrick.run
```

Don't hesitate to look at the specs for more examples ;-)

## TODO

* Release the gem with another name
* Complete the specs
* Implements the download and upload methods for the Net::HTTP backend

## Issues or Suggestions

Found an issue or have a suggestion? Please report it on
[Github's issue tracker](http://github.com/af83/ucengine.em/issues).

First you must have an ucengine instance goto the source directory and start:

    make run

Once the console started successfully, in an other shell

    ./rel/ucengine/bin/demo.sh localhost

If you wants to make a pull request, please check the specs before:

    rake test


Copyright (c) 2011 af83, released under the LGPL license
