module UCEngine
  class Client
    class HttpError < StandardError
      attr_reader :code, :description, :uri

      def initialize code, description, uri=nil
        @code = code
        @description = description
        @uri = uri
      end

      def to_s
        "<#{self.class.name} ##{@code} \"#{@description}\" #{@uri}>"
      end
    end

    class UCError < HttpError
    end
  end
end

