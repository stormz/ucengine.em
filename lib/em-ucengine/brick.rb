require 'em-ucengine/utils'

module EventMachine
  module UCEngine
    # Brick
    module Brick

      def self.included(klass)
        klass.extend(ClassMethods)
      end

      module ClassMethods

        def self.extended(klass)
          klass.class_eval {
            class_variable_set("@@routes", {})
            class_variable_set("@@bricks", [])
            class_variable_set("@@bootstrap", Proc.new {})
          }
        end

        # Define a bootstrap
        # Called before subscribing to events
        def bootstrap(&block)
          class_variable_set("@@bootstrap", block)
        end

        # Define and event handler
        #
        # @param [String] route
        def on(route, &callback)
          routes = class_variable_get("@@routes")
          routes[route] ||= []
          routes[route] << callback
        end

        # add a sub-brick to the currentbrick
        #
        # @param [String] route
        def use(name)
          class_variable_get("@@bricks") << name
        end
      end

      attr_reader :uce

      # Start EventMachine, initialize and start the brick
      #
      # @param [Hash] config
      def self.run(config={})
        brick = self.new config
        EM::run do
          brick.start
        end
      end

      # Create a new brick
      #
      # @param [Hash] config
      def initialize(config={})
        @uce = nil
        @config = config
      end

      # Start the brick
      #
      # @param [EM::UCEngine::Client] uce the instance of the client, used with sub-brick
      def start(uce=nil)
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
        else
          @uce = uce
          self.instance_eval &bootstrap
        end
      end

      def bootstrap
        self.class.class_variable_get("@@bootstrap")
      end

      def routes
        self.class.class_variable_get("@@routes")
      end

      def bricks
        self.class.class_variable_get("@@bricks")
      end

      def after(n, &block)
        EventMachine::add_timer n, &block
      end

      def every(n, &block)
        EventMachine::add_periodic_timer n, &block
      end

      protected

      def ready(bricks_instances)
        self.instance_eval &bootstrap

        r = routes.keys
        bricks_instances.each do |brick|
          r += brick.routes.keys
        end
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
