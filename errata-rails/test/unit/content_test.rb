require 'test_helper'

class ContentTest < ActiveSupport::TestCase

  setup do
    @content = RHBA.active.last.content
  end

  test "setup sanity" do
    assert @content.valid?
  end

  test "under limit description passes validation" do
    @content.description = "123456789 " * 399
    assert @content.valid?
  end

  test "on limit description passes validation" do
    @content.description = "123456789 " * 400
    assert @content.valid?
  end

  test "over limit description fails validation" do
    @content.description = "123456789 " * 401
    refute @content.valid?
    assert_errors_include @content, "Description length is 4009 which is longer than the 4000 character limit."
  end

  test "over limit after formatting description fails validation also" do
    # (will convert > to &gt;)
    @content.description = "12345678> " * 399
    refute @content.valid?
    assert_errors_include @content, "Description length after formatting and wrapping is 5187 which is longer than the 4000 character limit. (Unformatted length is 3989)."
  end

  # (Bug 1142296)
  test "validation should not insert line breaks in description" do
    text = ("some text that might get wrapped " * 5).strip
    @content.description = text
    @content.valid?
    assert_equal text, @content.description
  end

end
