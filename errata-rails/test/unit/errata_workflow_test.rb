require 'test_helper'

class ErrataWorkflowTest < ActiveSupport::TestCase

  test "text only workflow includes specific step" do
    assert rhba_async.text_only_steps.include? :set_text_only_rhn_channels
  end

  test "text only workflow includes cdn push options" do
    assert rhba_async.text_only_steps.include? :cdn_stage_push
    assert rhba_async.text_only_steps.include? :cdn_push
  end

end
