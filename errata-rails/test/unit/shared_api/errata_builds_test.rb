require 'test_helper'

class SharedApi::ErrataBuildsTest < ActiveSupport::TestCase
  include SharedApi::ErrataBuilds

  test 'remove builds ignores already missing builds' do
    # Mock this method to prevent error because this test is running outside
    # the controller and log_message is defined in the application controller.
    self.expects(:log_message).at_least_once.with(:info, instance_of(String))

    e = Errata.find(16397)
    bb = BrewBuild.find(30001)

    refute e.brew_builds.include?(bb)

    param = {bb.id => {:product_versions => {}}}
    e.available_product_versions.each do |pv|
      param[bb.id][:product_versions][pv.id] = {:file_types => nil}
    end

    assert_no_difference('ErrataBrewMapping.count') do
      got = self.remove_builds_from_errata(e, param)
      assert_equal e, got
    end
  end

  test "call show_notice should raise not implemented error" do
    error = assert_raises(NotImplementedError) do
      self.show_notice('build added successfully')
    end
    assert_equal "log_message method is not defined in the controller.", error.message
  end
end
