require "test_helper"
require "json"

module Capistrano
  module Harrow
    class APITest < Minitest::Test
      def test_sign_up_makes_a_POST_request_to_the_configured_endpoint_sending_json
        http = TestHTTPClient.new

        signup_data = {
          name: 'John Doe',
          email: 'john.doe@example.com',
          repository_url: 'git@github.com/example/example.git',
          password: 'longpassword',
        }

        api = API.new(url: 'https://www.app.harrow.io/api/', client: http)

        api.sign_up(signup_data)

        assert_equal 1, http.requests.length

        request = http.requests.first

        assert_equal 'POST', request.method
        assert_equal 'application/json', request['Content-Type']
        assert_equal '/api/capistrano/sign-up', request.path.to_s
        assert_equal signup_data.to_json, request.body
      end

      def test_sign_up_returns_response_data_in_case_of_validation_error
        validation_error = Net::HTTPResponse.new(1.1, 422, "Unacceptable Entity")
        def validation_error.body
          {reason: 'invalid', errors: {email: ['not_unique']}}.to_json
        end

        http = TestHTTPClient.new.
               respond_with(validation_error)

        api = API.new(url: 'https://www.app.harrow.io/api/', client: http)
        response_data = api.sign_up({})

        assert_includes response_data.keys, :errors
      end

      def test_sign_up_raises_a_protocol_error_in_case_of_a_non_2xx_response
        invalid_entity_response = Net::HTTPResponse.new(1.1, 422, "Unacceptable Entity")
        def invalid_entity_response.body; "{}"; end

        http = TestHTTPClient.new.
               respond_with(invalid_entity_response)

        api = API.new(url: 'https://www.app.harrow.io/api/', client: http)

        assert_raises(API::ProtocolError) do
          api.sign_up({})
        end
      end

      def test_sign_up_raises_an_fatal_error_for_any_other_exception
        http = TestHTTPClient.new.
               fail_with StandardError.new

        api = API.new(url: 'https://www.app.harrow.io/api/', client: http)

        assert_raises(API::FatalError) do
          api.sign_up({})
        end
      end

      def test_participating_makes_a_GET_request
        http = TestHTTPClient.new

        api = API.new(url: 'https://www.app.harrow.io/api/', client: http)

        api.participating?

        assert_equal 1, http.requests.length
        request = http.requests.first
        assert_equal 'GET', request.method
        assert_equal URI(API::PARTICIPATION_URL).path, URI(request.path).path
      end

      def test_participating_returns_value_from_json_response
        response = Net::HTTPOK.new('1.1', '200', 'OK').tap do |r|
          def r.body
            '{"participating": false}'
          end
        end

        http = TestHTTPClient.new.
               respond_with(response)

        api = API.new(url: 'https://www.app.harrow.io/api/', client: http)

        assert_equal false, api.participating?

        def response.body
          '{"participating": true}'
        end

        assert_equal true, api.participating?
      end

      def test_participating_returns_false_in_case_of_any_error
        response = Net::HTTPOK.new('1.1', '200', 'OK').tap do |r|
          def r.body
            '{"participating": false}'
          end
        end

        http = TestHTTPClient.new.
               fail_with(StandardError.new).
               respond_with(response)

        api = API.new(url: 'https://www.app.harrow.io/api/', client: http)

        assert_equal false, api.participating?
      end

      def test_participating_includes_sign_up_data_as_query_parameters
        signup_data = {
          name: 'John Doe',
          email: '',
          repository_url: 'https://github.com/john-doe/example.git',
        }

        http = TestHTTPClient.new

        api = API.new(url: 'https://www.app.harrow.io/api/', client: http)

        repository_digest = Digest::SHA1.new.hexdigest(signup_data[:repository_url])

        api.participating?(signup_data)

        expected_params = {
          'name_present' => 'true',
          'email_present' => 'false',
          'repository_id' => repository_digest,
        }

        assert_equal 1, http.requests.length
        request = http.requests.first
        params_sent = Hash[URI.decode_www_form(URI.parse(request.path).query)]
        assert_equal 'GET', request.method
        assert_equal expected_params, params_sent
      end

      def test_it_sets_the_user_agent_based_on_this_gem_and_ruby_version_and_git_version
        Capistrano.const_set('VERSION','3.5.0') unless defined? Capistrano::VERSION

        http = TestHTTPClient.new
        api = API.new(url: 'https://www.app.harrow.io/api/', client: http)

        api.participating?

        git_version = `git --version`.split(' ').last

        request = http.requests.first
        user_agent = "capistrano-harrow=#{VERSION} capistrano=#{Capistrano::VERSION} ruby=#{RUBY_VERSION} git=#{git_version}"
        assert_equal user_agent, request['User-Agent']
      end
    end
  end
end
