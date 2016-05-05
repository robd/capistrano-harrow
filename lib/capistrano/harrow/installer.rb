# coding: utf-8
module Capistrano
  module Harrow
    class Installer
      PROMPTS = {
        want_install: %q{ Try it now? },
        enter_password: "Enter a password for your Harrow.io account",
        confirm_password: "Confirm your password",
        retry_request: "Retry?",
        enter_name: "Enter your name",
        enter_email: "Enter your email",
      }

      MESSAGES = {
        aborting: "Aborting%<reason>s...\n",
        installation_successful: %q{
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                    Success!                    ┃
┃                                                ┃
┃     You have been registered on Harrow.io.     ┃
┃                                                ┃
┃     Your organization is called:               ┃
┃                                                ┃
┃             %-35<organization_name>s┃
┃                                                ┃
┃     Your project is called:                    ┃
┃                                                ┃
┃             %-35<project_name>s┃
┃                                                ┃
┃     Log in here or check your email            ┃
┃     for an account confirmation link           ┃
┃                                                ┃
┃     https://www.app.harrow.io                  ┃
┃                                                ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
},
        existing_account_found: %q{
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                     Great!                     ┃
┃                                                ┃
┃         You already have an account!           ┃
┃                                                ┃
┃         Please log in at:                      ┃
┃                                                ┃
┃         https://www.app.harrow.io              ┃
┃                                                ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
},
        password_mismatch: "Passwords don't match!",
        api_network_error: "Looks like there was a problem with the network",
        api_protocol_error: "Harrow API declined request",
        api_fatal_error: "Something went wrong",
        password_too_short: "Your password needs to be at least 10 characters long",
        signup_data: %q{

We'll set-up your account for you with the following
details:

  %<name>s <%<email>s>

},
        repository: %{
For this repository with the URL:

  %<repository_url>s

},
   preinstall: %q{
 - Free for small projects!

 - Test, deploy and collaborate online easily
   using tools you already know and love!

 - Trigger tasks automatically based on Git changes
   and webhooks. Get notified by email, slack, etc.

 - Works seamlessly for PHP, Node.js, Ansible, Python, Go,
   Capistrano and more!

},

      }

      def message(tag, format_data)
        sprintf(@messages.fetch(tag, tag.to_s), format_data)
      end

      def prompt(tag)
        @prompts.fetch(tag, tag.to_s)
      end

      def initialize(params={ui: UI::TTY, api: API, config: Config::Git})
        @ui = params.fetch(:ui)
        @config = params.fetch(:config)
        @api = params.fetch(:api)
        @quit = false
        @password = nil
        update_message_catalog!({messages: MESSAGES,
                                 prompts: PROMPTS})
      end

      def install!
        return if @config.disabled?
        return if @config.installed?
        messages = @api.participating?(signup_data)
        return unless messages
        update_message_catalog!(messages)

        @ui.show Banner.new.to_s
        @ui.show message(:preinstall, {})

        begin
          if @ui.prompt(prompt(:want_install)).downcase == 'no'
            quit!
            return
          end
        rescue UI::TimeoutError
          quit!("timeout")
          return
        end

        data = signup_data
        if data[:email].to_s.empty? or data[:name].to_s.empty?
          begin
            data[:name] = @ui.prompt(prompt(:enter_name), [])
            data[:email] = @ui.prompt(prompt(:enter_email), [])
          rescue UI::TimeoutError
            quit!("timeout")
          end
        end

        @ui.show message(:signup_data, data)
        unless data[:repository_url].to_s.empty?
          @ui.show message(:repository, data)
        end

        @password = prompt_password!
        unless @password
          quit!("no password provided")
          return
        end

        sign_up_user!
      end

      def signup_data
        {
          repository_url: @config.repository_url,
          name: @config.username,
          email: @config.email,
          password: @password,
        }
      end

      def quit!(reason="")
        unless reason.empty?
          reason = ": #{reason}"
        end

        @quit = true
        @ui.show(message(:aborting,{reason: reason}))
      end

      def quit?
        @quit
      end

      private
      def sign_up_user!
        begin
          response_data = @api.sign_up(signup_data)
          @config.session_uuid = response_data[:session_uuid]
          @config.project_uuid = response_data[:project_uuid]
          @config.organization_uuid = response_data[:organization_uuid]
          if response_data.fetch(:reason, 'ok') == 'invalid'
            if response_data.fetch(:errors, {}).fetch(:email, []).first == 'not_unique'
              @ui.show message(:existing_account_found, {})
              return :account_exists
            else
              @ui.show message(:api_fatal_error, {})
              return response_data
            end
          else
            @ui.show message(:installation_successful, response_data)
            return :signed_up
          end
        rescue API::NetworkError
          @ui.show message(:api_network_error, {})
          should_retry = false
          begin
            if @ui.prompt(prompt(:retry_request), [:no, :yes]) == :yes
              should_retry = true
            end
          rescue UI::TimeoutError
            quit!
            return
          end

          retry if should_retry
        rescue API::ProtocolError
          quit! message(:api_protocol_error, {})
          return
        rescue API::FatalError
          quit! message(:api_fatal_error, {})
          return
        end
      end

      def prompt_password!
        tries = 3
        while tries > 0
          password = @ui.prompt_password(prompt(:enter_password))
          confirmed_password = @ui.prompt_password(prompt(:confirm_password))


          if password == confirmed_password && password.to_s.length >= 10
            return password
          elsif password.to_s.length < 10
            @ui.show message(:password_too_short, {})
          else
            @ui.show message(:password_mismatch, {})
          end

          tries = tries - 1
        end
      end

      def update_message_catalog!(new_messages)
        return unless new_messages.respond_to? :fetch
        @messages = {} unless @messages
        @prompts = {} unless @prompts

        @messages.merge!(new_messages.fetch(:messages, {}))
        @prompts.merge!(new_messages.fetch(:prompts, {}))
      end

    end
  end
end
