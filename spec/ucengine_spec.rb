require "rspec"
require "em-ucengine"

describe EventMachine::UCEngine do
  let (:uce) { EventMachine::UCEngine.new }

  it "fetches /time from UCEngine" do
    EM.run do
      uce.time { |response|
        EM.stop
        response.should be
      }
    end
  end
end
