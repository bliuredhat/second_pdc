require 'test_helper'

class PushHelperTest < ActiveSupport::TestCase
  include PushHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::FormTagHelper

  setup do
    @errata = Errata.find(10836)
  end

  #
  # This is a method from WorkflowHelper to render the last successful
  # push. Since including WorkflowHelper will suck in more dependencies,
  # we just emulate the method here.
  #
  def last_push_link(push_job_class, errata)
    "<a href='#'>Last job</a>"
  end

  #
  # Bug: 1069980
  #
  test "renders checked checkbox without successful push in the past" do
    policy = Push::Policy.new(@errata, :rhn_live)
    refute @errata.send(:has_pushed_rhn_live?)
    assert_match %r{checked="checked}, render_push_target(policy)
  end

  #
  # Successful push, no need to have this push type checked by
  # default, but a link to the last successful job.
  #
  test "renders unchecked checkbox with successful push" do
    @errata.stubs(:has_pushed_since_last_respin?).returns(true)
    result = render_push_target(Push::Policy.new(@errata, :rhn_live))

    assert_no_match %r{checked="}, result
    assert_match %r{Last job}, result
  end

end
