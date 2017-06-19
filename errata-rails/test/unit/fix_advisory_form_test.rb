require 'test_helper'

class FixAdvisoryFormTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  def setup
    @model = FixAdvisoryForm.new Errata.last
    @text_only_rhba = RHBA.shipped_live.last
    @text_only_rhba.update_attribute(:text_only, 1)
  end

  # see Bug: 1104521
  test "RHBA text only advisories are valid for CPE change" do
    assert_valid FixAdvisoryForm.new(RHSA.shipped_live.where(:text_only => 1).last)
    assert_valid FixAdvisoryForm.new(@text_only_rhba)
  end

end
