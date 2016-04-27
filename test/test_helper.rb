$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'capistrano/harrow'
require 'minitest/autorun'
require 'uri'

class TestUI
  def initialize(answers = {})
    @prompted = []
    @password_prompted = []
    @shown = []
    @answers = answers
    @timeouts = {}
    @default_answers = {}
  end

  def add_answer(question, answer)
    @answers[question] = Array(answer)
    self
  end

  def show(text)
    @shown << text
    self
  end

  def shown
    @shown
  end

  def timeout_prompt!(prompt_str)
    @timeouts[prompt_str] = true
  end

  def prompt_password(prompt_str)
    raise Capistrano::Harrow::UI::TimeoutError.new if @timeouts.key? prompt_str
    @password_prompted << prompt_str
    @answers.fetch(prompt_str, ['']).shift
  end

  def default_answers_for(prompt_str)
    @default_answers.fetch(prompt_str, [])
  end

  def prompt(prompt_str, answers=[:yes,:no])
    raise Capistrano::Harrow::UI::TimeoutError.new if @timeouts.key? prompt_str
    @prompted << prompt_str
    @default_answers[prompt_str] = answers
    @answers.fetch(prompt_str, [answers.first]).shift
  end

  def password_prompts
    @password_prompted
  end

  def prompts
    @prompted
  end
end

class TestConfig
  attr_accessor :session_uuid, :project_uuid, :organization_uuid

  def disabled?; false; end
  def installed?; false; end
  def username;  'John Doe'; end
  def email; 'john.doe@example.com'; end
  def repository_url; 'git@github.com:john-doe/example.git'; end
end

class TestHarrowAPI
  def initialize
    @requests = []
    @fail_with = {}
    @responses = {}
  end

  def use_default_responses!
    respond_to(:sign_up, {
                 session_uuid: "0b69d52d-0e50-4c26-a77a-ea3f147fa5fd",
                 organization_uuid: "6fad521f-b5da-4bec-9a0d-028085d78c47",
                 project_uuid: "b178f89e-4135-4071-b8dc-f0ac77e3f3cf",
                 organization_name: "john-doe",
                 project_name: "example",
               })
  end

  def respond_to(request, response_data)
    @responses[request] = response_data

    self
  end

  def participating?(params={})
    @requests << {url: 'http://harrow.capistranorb.com',
                  method: 'GET',
                  params: params,
    }
    true
  end

  def fail(request_type, error)
    @fail_with[request_type] = error

    self
  end

  def sign_up(data)
    raise @fail_with[:sign_up] if @fail_with.key? :sign_up
    @requests << {url: 'https://www.app.harrow.io/api/capistrano/sign-up',
                  method: 'POST',
                  data: data}
    @responses.fetch(:sign_up, {})
  end

  def requests
    @requests
  end
end

class TestHTTPClient
  def initialize
    @requests = []
    @response = Net::HTTPOK.new('1.1', '200', "OK").tap do |res|
      def res.body; "{}"; end
    end
    @exception = nil
  end

  def fail_with(exception)
    @exception = exception

    self
  end

  def respond_with(response)
    @response = response

    self
  end

  def get(url, headers, params)
    raise @exception if @exception

    params = URI.encode_www_form(params)
    request = Net::HTTP::Get.new(url.merge('?'+params).to_s)
    headers.each do |header, value|
      request[header.to_s] = value
    end

    @requests << request

    @response
  end

  def post(url, headers, data)
    raise @exception if @exception

    request = Net::HTTP::Post.new(url.path)
    headers.each do |header, value|
      request[header.to_s] = value
    end
    request.body = data

    @requests << request

    @response
  end

  def requests
    @requests
  end
end
