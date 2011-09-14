
module EventMachine
  module UCEngine
    module Client
      class HttpError < StandardError
        attr_reader :code, :description, :uri

        def initialize code, description, uri=nil
          @code = code
          @description = description
          @uri = uri
        end
      end

      class UCError < HttpError
      end
    end
  end
end
