module EventMachine
  module UCEngine
    module Brick
      # A simple class to allowing you to test your bricks
      module Test
        class FakeUce < ::MiniTest::Mock
          def publish(*args)
          end
        end

        # Return the instance of the brick
        def brick
          return @b unless @b.nil?
          @b = app.new
          @b.start FakeUce.new
          @b
        end

        # Trigger a U.C.Engine event into the brick
        #
        # @param [String] name
        # @param [Hash] data
        def trigger(name, data={})
          event = data.merge "type" => name
          brick.routes[name].each do |proc|
            brick.instance_exec(event, &proc)
          end unless brick.routes[name].nil?
        end
      end
    end
  end
end
