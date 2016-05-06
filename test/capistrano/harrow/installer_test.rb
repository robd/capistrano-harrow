require 'test_helper'

module Capistrano
  module Harrow
    class InstallerTest < Minitest::Test
      def test_it_does_not_make_an_http_request_and_exists_silently_if_harrow_is_disabled
        ui = TestUI.new

        config = TestConfig.new.tap do |o|
          def o.disabled?
            true
          end
        end

        api = TestHarrowAPI.new
        harrow = Installer.new(ui: ui, config: config, api: api)
        harrow.install!

        assert_equal [], api.requests
        assert_equal [], ui.prompts

      end

      def test_it_does_not_prompt_for_installing_harrow_when_harrow_is_installed_already
        ui = TestUI.new

        config = TestConfig.new.tap do |o|
          def o.installed?
            true
          end
        end

        harrow = Installer.new(ui: ui, config: config, api: TestHarrowAPI.new)
        harrow.install!

        assert_equal [], ui.prompts
      end

      def test_it_aborts_in_case_of_a_protocol_error
        ui = TestUI.new
        config = TestConfig.new
        harrowAPI = TestHarrowAPI.new
        harrowAPI.fail :sign_up, API::ProtocolError.new
        harrow = Installer.new(ui: ui, config: config, api: harrowAPI)
        ui.
          add_answer(harrow.prompt(:enter_password), 'longpassword').
          add_answer(harrow.prompt(:confirm_password), 'longpassword')

        harrow.install!

        assert_includes ui.shown, "Aborting: Harrow API declined request...\n"
      end

      def test_it_shows_a_success_message_if_the_signup_was_successful
        ui = TestUI.new
        organization_name = "john-doe"
        project_name = "example"
        response_data =  {session_uuid: "a13d665b-34ea-4efe-9969-3068a2c665bc",
                          organization_uuid: "054c2bf9-9c8d-497b-8821-132932dbcc1a",
                          project_uuid: "8855abbb-d101-4e35-8dc1-f19da442e62e",
                          organization_name: organization_name,
                          project_name: project_name,
                         }
        harrowAPI = TestHarrowAPI.new.
                    respond_to(:sign_up,response_data)

        config = TestConfig.new
        harrow = Installer.new(ui: ui, config: config, api: harrowAPI)
        ui.
          add_answer(harrow.prompt(:enter_password), 'longpassword').
          add_answer(harrow.prompt(:confirm_password), 'longpassword')


        harrow.install!

        assert_includes ui.shown, harrow.message(:installation_successful, response_data.merge(email: 'john.doe@example.com'))
      end

      def test_it_shows_a_success_message_if_the_user_is_already_registered
        ui = TestUI.new
        response_data =  {
          reason: 'invalid',
          errors: {email: ['not_unique']},
        }
        harrowAPI = TestHarrowAPI.new.
                    respond_to(:sign_up,response_data)

        config = TestConfig.new
        harrow = Installer.new(ui: ui, config: config, api: harrowAPI)
        ui.
          add_answer(harrow.prompt(:enter_password), 'longpassword').
          add_answer(harrow.prompt(:confirm_password), 'longpassword')


        harrow.install!

        assert_includes ui.shown, harrow.message(:existing_account_found, {})
      end

      def test_it_aborts_in_case_of_a_fatal_error
        ui = TestUI.new
        config = TestConfig.new
        harrowAPI = TestHarrowAPI.new
        harrowAPI.fail :sign_up, API::FatalError.new
        harrow = Installer.new(ui: ui, config: config, api: harrowAPI)
        ui.
          add_answer(harrow.prompt(:enter_password), 'longpassword').
          add_answer(harrow.prompt(:confirm_password), 'longpassword')


        harrow.install!

        assert_includes ui.shown, "Aborting: Something went wrong...\n"
      end

      def test_it_shows_a_banner_if_harrow_is_not_installed_yet
        ui = TestUI.new

        config = TestConfig.new

        harrow = Installer.new(ui: ui, config: config, api: TestHarrowAPI.new)

        harrow.install!

        banner = Banner.new
        assert_equal true, ui.shown.any? { |message| banner.variants.include? message}
      end

      def test_it_shows_a_preinstall_message_if_harrow_is_not_installed
        ui = TestUI.new

        config = TestConfig.new

        harrow = Installer.new(ui: ui, config: config, api: TestHarrowAPI.new)

        harrow.install!

        assert_includes ui.shown, harrow.message(:preinstall, {})
      end

      def test_it_quits_if_the_user_answers_with_no
        ui = TestUI.new

        config = TestConfig.new

        harrow = Installer.new(ui: ui, config: config, api: TestHarrowAPI.new)
        ui.add_answer(harrow.prompt(:want_install), :no)
        harrow.install!

        assert_equal true, harrow.quit?
      end

      def test_it_quits_if_the_user_has_not_answered_within_thirty_seconds
        ui = TestUI.new

        config = TestConfig.new

        harrow = Installer.new(ui: ui, config: config, api: TestHarrowAPI.new)

        ui.timeout_prompt! harrow.prompt(:want_install)

        harrow.install!

        assert_equal true, harrow.quit?
      end

      def test_it_presents_the_user_with_account_information_it_gathered
        ui = TestUI.new

        config = TestConfig.new

        harrow = Installer.new(ui: ui, config: config, api: TestHarrowAPI.new)

        expected = harrow.message(:signup_data,
                                     { :name => config.username,
                                       :email => config.email,
                                       :repository_url => config.repository_url,
                                     }
                                    )

        harrow.install!

        assert_includes ui.shown, expected
        assert_includes ui.shown, harrow.message(:repository, {repository_url: config.repository_url})
      end

      def test_it_does_not_show_the_repository_url_if_it_is_empty
        ui = TestUI.new

        default_repository = TestConfig.new.repository_url
        config = TestConfig.new.tap do |c|
          def c.repository_url; ''; end
        end

        harrow = Installer.new(ui: ui, config: config, api: TestHarrowAPI.new)

        harrow.install!

        assert_includes ui.shown, harrow.message(:signup_data, harrow.signup_data)
        refute_includes ui.shown, harrow.message(:repository, {repository_url: default_repository})
      end

      def test_it_asks_the_user_for_a_password
        ui = TestUI.new
        config = TestConfig.new
        harrow = Installer.new(ui: ui, config: config, api: TestHarrowAPI.new)
        harrow.install!

        assert_includes ui.password_prompts, harrow.prompt(:enter_password)
      end

      def test_it_asks_the_user_to_confirm_the_password
        ui = TestUI.new
        config = TestConfig.new
        harrow = Installer.new(ui: ui, config: config, api: TestHarrowAPI.new)
        harrow.install!

        assert_includes ui.password_prompts, harrow.prompt(:confirm_password)
      end

      def test_it_asks_the_user_for_a_password_up_to_three_times_if_the_confirmation_failed
        ui = TestUI.new
        config = TestConfig.new
        harrow = Installer.new(ui: ui, config: config, api: TestHarrowAPI.new)
        ui.
          add_answer(harrow.prompt(:enter_password), ['a', 'a', 'a']).
          add_answer(harrow.prompt(:confirm_password), ['b', 'b', 'b'])


        harrow.install!

        prompts_for_password = ui.password_prompts.select do |prompt|
          prompt == harrow.prompt(:enter_password)
        end

        assert_equal 3,prompts_for_password.size
      end

      def test_it_quits_if_the_user_did_not_provide_a_password_with_three_tries
        ui = TestUI.new
        config = TestConfig.new
        harrow = Installer.new(ui: ui, config: config, api: TestHarrowAPI.new)
        ui.
          add_answer(harrow.prompt(:enter_password), 'a').
          add_answer(harrow.prompt(:confirm_password), 'b')


        harrow.install!

        assert_equal true, harrow.quit?
      end

      def test_it_registers_the_user_with_the_harrow_api
        ui = TestUI.new
        config = TestConfig.new
        harrowAPI = TestHarrowAPI.new.use_default_responses!
        harrow = Installer.new(ui: ui, config: config, api: harrowAPI)
        ui.
          add_answer(harrow.prompt(:enter_password), 'longpassword').
          add_answer(harrow.prompt(:confirm_password), 'longpassword')


        harrow.install!

        expected_request = {
          url: 'https://www.app.harrow.io/api/capistrano/sign-up',
          method: 'POST',
          data: {
            name: config.username,
            email: config.email,
            repository_url: config.repository_url,
            password: 'longpassword',
          }
        }

        assert_includes harrowAPI.requests, expected_request
      end

      def test_it_asks_the_user_to_try_again_if_talking_to_the_harrow_api_fails
        ui = TestUI.new
        config = TestConfig.new
        harrowAPI = TestHarrowAPI.new
        harrowAPI.fail :sign_up, API::NetworkError.new
        harrow = Installer.new(ui: ui, config: config, api: harrowAPI)
        ui.
          add_answer(harrow.prompt(:enter_password), 'longpassword').
          add_answer(harrow.prompt(:confirm_password), 'longpassword')


        harrow.install!

        assert_includes ui.shown, harrow.message(:api_network_error, {})
        assert_includes ui.prompts, harrow.prompt(:retry_request)

      end

      def test_it_times_out_when_asking_for_a_retry_after_thirty_seconds
        ui = TestUI.new
        config = TestConfig.new

        harrowAPI = TestHarrowAPI.new
        harrowAPI.fail :sign_up, API::NetworkError.new
        harrow = Installer.new(ui: ui, config: config, api: harrowAPI)

        ui.timeout_prompt! harrow.prompt(:retry_request)

        ui.
          add_answer(harrow.prompt(:enter_password), 'longpassword').
          add_answer(harrow.prompt(:confirm_password), 'longpassword')


        harrow.install!

        assert_equal true, harrow.quit?
      end

      def test_it_requires_the_password_to_be_longer_than_nine_characters
        ui = TestUI.new
        config = TestConfig.new

        harrowAPI = TestHarrowAPI.new.use_default_responses!
        harrow = Installer.new(ui: ui, config: config, api: harrowAPI)
        ui.
          add_answer(harrow.prompt(:enter_password), ['a', '1234567890']).
          add_answer(harrow.prompt(:confirm_password), ['a', '1234567890'])


        harrow.install!

        assert_includes ui.shown, harrow.message(:password_too_short, {})
      end

      def test_it_stores_the_harrow_session_uuid_in_local_configuration
        ui = TestUI.new
        config = TestConfig.new

        session_uuid = "1998e74d-fd0e-4309-a258-49fa63a5c00c"
        organization_uuid = "508d9001-16d9-41df-a361-2808e99bca68"
        project_uuid = "a9759944-816f-4971-9a8c-07549770b8c6"
        organization_name = "john-doe"
        project_name = "example"
        harrowAPI = TestHarrowAPI.new.
                    respond_to(:sign_up, {session_uuid: session_uuid,
                                          organization_uuid: organization_uuid,
                                          project_uuid: project_uuid,
                                          organization_name: organization_name,
                                          project_name: project_name,
                                         })
        harrow = Installer.new(ui: ui, config: config, api: harrowAPI)

        ui.
          add_answer(harrow.prompt(:enter_password), ['a', '1234567890']).
          add_answer(harrow.prompt(:confirm_password), ['a', '1234567890'])


        harrow.install!

        assert_equal session_uuid, config.session_uuid

      end

      def test_it_stores_the_harrow_project_uuid_in_local_configuration
        ui = TestUI.new
        config = TestConfig.new

        session_uuid = "1998e74d-fd0e-4309-a258-49fa63a5c00c"
        organization_uuid = "508d9001-16d9-41df-a361-2808e99bca68"
        project_uuid = "a9759944-816f-4971-9a8c-07549770b8c6"
        organization_name = "john-doe"
        project_name = "example"
        harrowAPI = TestHarrowAPI.new.
                    respond_to(:sign_up, {session_uuid: session_uuid,
                                          organization_uuid: organization_uuid,
                                          project_uuid: project_uuid,
                                          organization_name: organization_name,
                                          project_name: project_name,
                                         })
        harrow = Installer.new(ui: ui, config: config, api: harrowAPI)
        ui.
          add_answer(harrow.prompt(:enter_password), ['a', '1234567890']).
          add_answer(harrow.prompt(:confirm_password), ['a', '1234567890'])


        harrow.install!

        assert_equal project_uuid, config.project_uuid

      end

      def test_it_stores_the_harrow_organization_uuid_in_local_configuration
        ui = TestUI.new
        config = TestConfig.new

        session_uuid = "1998e74d-fd0e-4309-a258-49fa63a5c00c"
        organization_uuid = "508d9001-16d9-41df-a361-2808e99bca68"
        project_uuid = "a9759944-816f-4971-9a8c-07549770b8c6"
        organization_name = "john-doe"
        project_name = "example"
        harrowAPI = TestHarrowAPI.new.
                    respond_to(:sign_up, {session_uuid: session_uuid,
                                          organization_uuid: organization_uuid,
                                          project_uuid: project_uuid,
                                          organization_name: organization_name,
                                          project_name: project_name,
                                         })
        harrow = Installer.new(ui: ui, config: config, api: harrowAPI)
        ui.
          add_answer(harrow.prompt(:enter_password), ['a', '1234567890']).
          add_answer(harrow.prompt(:confirm_password), ['a', '1234567890'])


        harrow.install!

        assert_equal organization_uuid, config.organization_uuid

      end

      def test_it_prints_a_message_when_passwords_do_not_match
        ui = TestUI.new
        config = TestConfig.new
        harrow = Installer.new(ui: ui, config: config, api: TestHarrowAPI.new)
        ui.
          add_answer(harrow.prompt(:enter_password), 'longpassword1').
          add_answer(harrow.prompt(:confirm_password), 'longpassword2')


        harrow.install!

        assert_includes ui.shown, harrow.message(:password_mismatch, {})
      end

      def test_it_prints_a_short_message_when_aborting
        ui = TestUI.new
        config = TestConfig.new

        harrow = Installer.new(ui: ui, config: config, api: TestHarrowAPI.new)
        harrow.quit!

        assert_includes ui.shown, harrow.message(:aborting, {reason:''})
      end

      def test_it_asks_for_name_and_email_if_they_cannot_be_determined_from_config
        ui = TestUI.new

        config = TestConfig.new.tap do |o|
          def o.username; ''; end
          def o.email; ''; end
        end

        harrow = Installer.new(ui: ui, config: config, api: TestHarrowAPI.new)
        ui.add_answer(harrow.prompt(:want_install), 'yes')
        harrow.install!

        assert_includes ui.prompts, harrow.prompt(:enter_name)
        assert_includes ui.prompts, harrow.prompt(:enter_email)
      end

      def test_it_shows_no_default_answers_when_asking_for_a_username_and_email
        ui = TestUI.new

        config = TestConfig.new.tap do |o|
          def o.username; ''; end
          def o.email; ''; end
        end

        harrow = Installer.new(ui: ui, config: config, api: TestHarrowAPI.new)
        ui.add_answer(harrow.prompt(:want_install), 'yes')
        harrow.install!

        assert_equal [], ui.default_answers_for(harrow.prompt(:enter_name))
        assert_equal [], ui.default_answers_for(harrow.prompt(:enter_email))
      end

      def test_it_reports_sign_up_data_when_checking_for_participation
        ui = TestUI.new

        config = TestConfig.new

        api = TestHarrowAPI.new
        harrow = Installer.new(ui: ui, config: config, api: api)
        harrow.install!

        assert_includes api.requests, {url: 'http://harrow.capistranorb.com',
                                       method: 'GET',
                                       params: harrow.signup_data}
      end

      def test_it_silently_quits_if_the_api_reports_no_participation
        ui = TestUI.new
        config = TestConfig.new
        harrowAPI = TestHarrowAPI.new.tap do |o|
          def o.participating?(params={})
            false
          end
        end

        harrow = Installer.new(ui: ui, config: config, api: harrowAPI)
        harrow.install!

        assert_empty ui.shown
      end

      def test_it_uses_the_messages_supplied_in_the_response_to_the_participation_call
        ui = TestUI.new
        config = TestConfig.new
        harrowAPI = TestHarrowAPI.new.tap do |o|
          def o.participating?(params={})
            {prompts: {
               want_install: 'TEST_WANT_INSTALL',
             },
             messages: {
               aborting: 'TEST_ABORTING',
             },
            }
          end
        end

        harrow = Installer.new(ui: ui, config: config, api: harrowAPI)
        harrow.install!

        assert_equal 'TEST_ABORTING', harrow.message(:aborting, {reason: 'none'})
        assert_equal 'TEST_WANT_INSTALL', harrow.prompt(:want_install)
      end

      def test_it_uses_default_messages_if_no_messages_are_supplied_in_the_response
        ui = TestUI.new
        config = TestConfig.new
        harrowAPI = TestHarrowAPI.new.tap do |o|
          def o.participating?(params={})
            true
          end
        end

        harrow = Installer.new(ui: ui, config: config, api: harrowAPI)
        harrow.install!

        assert_equal "Aborting: none...\n", harrow.message(:aborting, {reason: ': none'})
        assert_equal Installer::PROMPTS[:want_install], harrow.prompt(:want_install)
      end

      def test_it_uses_messages_from_the_gem_for_non_overridden_messages
        ui = TestUI.new
        config = TestConfig.new
        harrowAPI = TestHarrowAPI.new.tap do |o|
          def o.participating?(params={})
            {messages: {}, prompts: {}}
          end
        end

        harrow = Installer.new(ui: ui, config: config, api: harrowAPI)

        harrow.install!

        assert_equal "Aborting: none...\n", harrow.message(:aborting, {reason: ': none'})
        assert_equal Installer::PROMPTS[:want_install], harrow.prompt(:want_install)
      end
    end
  end
end
