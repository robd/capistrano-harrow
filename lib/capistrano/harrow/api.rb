require 'json'

module Capistrano
  module Harrow
    class API
      PARTICIPATION_URL = 'http://harrow.capistranorb.com/participate'

      class NetworkError < StandardError; end
      class ProtocolError < StandardError; end
      class FatalError < StandardError; end

      def initialize(params={url: 'https://www.app.harrow.io/api/',
                             client: HTTP,
                             participation_url: PARTICIPATION_URL,
                            })
        @url = URI(params.fetch(:url))
        @client = params.fetch(:client)
        @participation_url = URI(params.fetch(:participation_url, PARTICIPATION_URL))
      end

      def participating?
        response = @client.get(
          @participation_url,
          {'User-Agent' => user_agent},
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
            {'Content-Type' => 'application/json',
             'User-Agent' => user_agent,
            },
            data.to_json,
          )
        rescue StandardError => e
          raise FatalError.new(e)
        end

        response_code = response.code.to_i
        if response_code >= 200 && response_code < 300
          JSON.parse(response.body, symbolize_names: true)
        elsif response_code == 422
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
