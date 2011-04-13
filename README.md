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

    gem "em-ucengine", "~>0.1"

Then, you can use it in your code:

    require "em-ucengine"


TODO
----

* Files API
* ACL or Roles API
* Better error handling
* Complete the specs
* Compatibility with em-synchrony


Issues or Suggestions
---------------------

Found an issue or have a suggestion? Please report it on
[Github's issue tracker](http://github.com/af83/ucengine.em/issues).

If you wants to make a pull request, please check the specs before:

    rspec spec


Copyright (c) 2011 af83, released under the LGPL license
