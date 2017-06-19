require 'test_helper'

class DocsHelperTest < ActiveSupport::TestCase
  include DocsHelper

  test "don't throw exceptions sorting an advisory with a bogus status" do
    assert_equal '000099999999', reverse_alpha_sort_index('QE')
    assert_equal '000100000001', reverse_alpha_sort_index('qE')
    assert_equal '000100000001', reverse_alpha_sort_index('Bananas')
  end
end
