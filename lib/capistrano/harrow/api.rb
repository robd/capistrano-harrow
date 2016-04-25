require 'json'

module Capistrano
  module Harrow
    class API
      PARTICIPATION_URL = 'http://harrow.capistranorb.com/participate'

      class NetworkError < StandardError; end
      class ProtocolError < StandardError; end
      class FatalError < StandardError; end

      def initialize(url:,client:,participation_url: PARTICIPATION_URL)
        @url = URI(url)
        @client = client
        @participation_url = URI(participation_url)
      end

      def participating?
        response = @client.get(
          @url.merge(@participation_url),
          {'User-Agent': user_agent},
          {}
        )

        case response
        when Net::HTTPSuccess
          return ::JSON.parse(response.body, symbolize_names: true).fetch(:participating, false)
        end

        false
      rescue
        false
      end

      def sign_up(data)
        begin
          response = @client.post(
            @url.merge(@url.path + '/capistrano/sign-up'),
            {'Content-Type': 'application/json',
             'User-Agent': user_agent,
            },
            data.to_json,
          )
        rescue StandardError => e
          raise FatalError.new(e)
        end

        case response
        when Net::HTTPSuccess
          JSON.parse(response.body, symbolize_names: true)
        when Net::HTTPUnprocessableEntity
          data = JSON.parse(response.body, symbolize_names: true)
          if data.fetch(:reason, 'ok') == 'invalid'
            data
          else
            raise ProtocolError.new(response)
          end
        else
          raise ProtocolError.new(response)
        end
      end

      private

      def user_agent
        result = "capistrano-harrow=#{Capistrano::Harrow::VERSION}"
        result << " capistrano=#{Capistrano::VERSION}" if defined? Capistrano::VERSION
        result << " ruby=#{RUBY_VERSION}"

        result
      end

    end
  end
end
