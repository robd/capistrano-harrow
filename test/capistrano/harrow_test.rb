require 'test_helper'

class Capistrano::HarrowTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Capistrano::Harrow::VERSION
  end
end
