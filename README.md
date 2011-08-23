EventMachine library for U.C.Engine
===================================

em-ucengine is a Ruby library for [U.C.Engine](http://ucengine.org/) powered
by [EventMachine](https://github.com/eventmachine/eventmachine). It can
connect, subscribe and publish events to U.C.Engine.


How to use it
-------------

Install with Rubygems:

    gem install em-ucengine

If you use bundler, add it to your `Gemfile`:

    gem "em-ucengine", "~>0.2"

Then, you can use it in your code:

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

Don't hesitate to look at the specs for more examples ;-)


TODO
----

* Complete the specs
* Compatibility with em-synchrony

Issues or Suggestions
---------------------

Found an issue or have a suggestion? Please report it on
[Github's issue tracker](http://github.com/af83/ucengine.em/issues).

First you must have an ucengine instance goto the source directory and start:

    make run

Once the console started successfully, in an other shell

    ./rel/ucengine/bin/demo.sh localhost

If you wants to make a pull request, please check the specs before:

    rake test


Copyright (c) 2011 af83, released under the LGPL license
