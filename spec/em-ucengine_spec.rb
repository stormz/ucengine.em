#!/usr/bin/env ruby

require "minitest/autorun"
require "em-ucengine"


describe EventMachine::UCEngine do
  describe "when not authentified" do

    before do
      @uce = EventMachine::UCEngine.new
    end

    it "fetches /time from UCEngine" do
      EM.run do
        @uce.time do |response|
          EM.stop
          response.wont_be_nil
        end
      end
    end

  end
end
