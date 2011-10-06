module EventMachine
  module UCEngine
    module Brick
      module Test
        class FakeUce < ::MiniTest::Mock
          def publish(*args)
          end
        end

        def brick
          return @b unless @b.nil?
          @b = app.new
          @b.start uce
          @b
        end

        def uce
          FakeUce.new
        end

        def trigger(name)
          event = { "type" => name }
          brick.routes[name].each do |proc|
            brick.instance_exec(event, &proc)
          end
        end
      end
    end
  end
end
