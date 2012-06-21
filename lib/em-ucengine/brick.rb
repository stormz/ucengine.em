require 'em-ucengine/utils'

module EventMachine
  module UCEngine
    # This module allows to create a new brick for UCE. A brick may be either
    # an independent entity or a composition of several bricks, resulting in a
    # "meta-brick". On this case, only the meta-brick should be runned and only
    # one connection to UCE will be used.
    #
    # When creating a brick, one would provide a bootstrap block and declare at
    # least one event handler for the brick to manage. Handlers will be executed
    # in the context of the Brick instance, so one may also write arbitrary code
    # to be used in handlers blocks.
    #
    # See examples/bricks.rb and specs for more details.
    module Brick
      def self.included(klass)
        klass.extend(ClassMethods)
      end

      # Methods defined here will be made available as class methods on the
      # class including Brick. Some class variables are pushed as well:
      # +@@routes+, +@@bricks+, +@@bootstrap+.
      module ClassMethods

        def self.extended(klass)
          klass.class_eval {
            class_variable_set("@@routes", {})
            class_variable_set("@@bricks", [])
            class_variable_set("@@bootstrap", Proc.new {})
          }
        end

        # Define a bootstrap block, which will be called before subscribing
        # to events.
        def bootstrap(&block)
          class_variable_set("@@bootstrap", block)
        end

        # Define an event handler.
        #
        # @param [String] route
        # @yield [Event] a callback to be executed when a matching event is received
        # @example
        #   on "my.event" do |event|
        #     # do something
        #   end
        #
        def on(route, &callback)
          routes = class_variable_get("@@routes")
          routes[route] ||= []
          routes[route] << callback
        end

        # Add a sub-brick to the current brick.
        #
        # @param [Constant] Brick's class/module name
        # @example
        #   use MySpecializedBrick
        def use(name)
          class_variable_get("@@bricks") << name
        end
      end

      attr_reader :uce

      # Create a new brick.
      #
      # @param [Hash] config
      def initialize(config={})
        @uce = nil
        @config = config
      end

      # Start EventMachine, initialize and start the brick.
      #
      # When composing several bricks, only the meta-brick should be
      # runned.
      #
      # @param [Hash] config
      def self.run(config={})
        brick = self.new config
        EM::run do
          brick.start
        end
      end

      # Start the brick.
      #
      # @param [EM::UCEngine::Client] uce (nil) shared instance of the client,
      #   used by sub-bricks when composing so that only one UCE connection is
      #   made and used
      def start(uce=nil)
        # Not in a sub-brick, connect to UCE.
        if uce.nil?
          @uce = EM::UCEngine::Client.new(@config[:host], @config[:port])
          @uce.connect(@config[:name], @config[:credential]) do |err, uce|
            @uce = uce
            ready(bricks.map do |brick|
              b = brick.new
              b.start @uce
              b
            end)
          end
        else # Sub-brick, init with the shared UCE client instance.
          @uce = uce
          call_bootstrap
        end
      end

      # Accessor for +@@bootstrap+.
      def bootstrap
        self.class.class_variable_get("@@bootstrap")
      end

      # Accessor for +@@routes+.
      def routes
        self.class.class_variable_get("@@routes")
      end

      # Accessor for +@@bricks+.
      def bricks
        self.class.class_variable_get("@@bricks")
      end

      # Wrapper around EventMachine's +Timer+. Pass it a block to be
      # executed after a time range.
      #
      # @param [Integer] n time range in milliseconds
      # @yield
      def after(n, &block)
        EventMachine::Timer.new(n, &block)
      end

      # Wrapper around EventMachine's +PeriodicTimer+. Pass it a block
      # to be executed on a defined time frame.
      #
      # @param [Integer] n time range in milliseconds
      # @yield
      def every(n, &block)
        EventMachine::PeriodicTimer.new(n, &block)
      end

      protected

      # Call the bootstrap block
      def call_bootstrap
        if bootstrap.arity == 0
          self.instance_eval &bootstrap
        elsif bootstrap.arity == 1
          self.instance_exec @config, &bootstrap
        end
      end

      # Hook sub-brick's declared event handlers into the event loop, by subscribing to
      # UCE core.
      #
      # @param [Array<Brick>] brick_instances
      def ready(bricks_instances)
        r = routes.keys

        # Bootstrap.
        call_bootstrap

        # Merge routes when composing bricks.
        bricks_instances.each do |brick|
          r += brick.routes.keys
        end

        # Subscribe to UCE for declared event handlers.
        @uce.subscribe "", :type => r.uniq.join(',') do |err, events|
          events.each do |event|
            routes[event["type"]].each do |callback|
              self.instance_exec(event, &callback)
            end unless routes[event["type"]].nil?
            bricks_instances.each do |brick|
              brick.routes[event["type"]].each do |callback|
                brick.instance_exec(event, &callback)
              end unless brick.routes[event["type"]].nil?
            end
          end
        end
      end
    end
  end
end
