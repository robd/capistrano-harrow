require "test_helper"
require 'tempfile'

module Capistrano
  module Harrow
    module Config
      class GitTest < Minitest::Test
        def setup
          @gitconfig = Tempfile.new('gitconfig')
        end

        def teardown
          @gitconfig.close!
          @gitconfig.unlink
        end

        def test_it_looks_for_a_harrow_session_uuid_to_determine_whether_harrow_is_installed
          config = Git.new(@gitconfig.path)

          assert_equal false, config.installed?
          config.session_uuid = "d7bb46d0-dc91-48d2-a8cb-2f8d97add90a"
          assert_equal true, config.installed?
        end

        def test_it_extracts_the_repository_url_from_the_origin_remote
          config = Git.new(@gitconfig.path)
          `git config --file=#{@gitconfig.path} remote.origin.url https://github.com/capistrano/capistrano`

          assert_equal 'https://github.com/capistrano/capistrano', config.repository_url
        end

        def test_it_extracts_the_username_from_the_user_name_key
          config = Git.new(@gitconfig.path)
          `git config --file=#{@gitconfig.path} user.name "John Doe"`

          assert_equal 'John Doe', config.username
        end

        def test_it_extracts_the_email_from_the_user_email_key
          config = Git.new(@gitconfig.path)
          `git config --file=#{@gitconfig.path} user.email "john.doe@example.com"`

          assert_equal 'john.doe@example.com', config.email
        end

        def test_it_stores_the_session_uuid_under_harrow_session_uuid
          config = Git.new(@gitconfig.path)
          session_uuid = "2210ee4f-df55-428a-9062-b6f5e40c02c1"
          config.session_uuid = session_uuid

          assert_equal session_uuid, `git config --file=#{@gitconfig.path} harrow.session.uuid`.chop
        end

        def test_it_stores_the_organization_uuid_under_harrow_organization_uuid
          config = Git.new(@gitconfig.path)
          organization_uuid = "898dfcfc-5bc0-4278-9e6c-0279dd89b18d"
          config.organization_uuid = organization_uuid

          assert_equal organization_uuid, `git config --file=#{@gitconfig.path} harrow.organization.uuid`.chop

        end

        def test_it_stores_the_project_uuid_under_harrow_project_uuid
          config = Git.new(@gitconfig.path)
          project_uuid = "4c747487-7efd-4925-b14b-0f987e09a50c"
          config.project_uuid = project_uuid

          assert_equal project_uuid, `git config --file=#{@gitconfig.path} harrow.project.uuid`.chop
        end

        def test_it_returns_disabled_if_harrow_disabled_is_set
          config = Git.new(@gitconfig.path)
          assert_equal false, config.disabled?
          `git config --file=#{@gitconfig.path} harrow.disabled true`
          assert_equal true, config.disabled?
        end

        def test_it_raises_configuration_backend_error_if_git_is_not_installed
          config = Git.new(@gitconfig.path)
          assert_raises(Capistrano::Harrow::Config::BackendError) do
            old_path = ENV['PATH']
            begin
              ENV['PATH'] = ''
              config.session_uuid
            ensure
              ENV['PATH'] = old_path
            end
          end
        end
      end
    end
  end
end
