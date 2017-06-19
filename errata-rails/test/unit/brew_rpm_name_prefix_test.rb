require 'test_helper'

class BrewRpmNamePrefixTest < ActiveSupport::TestCase

  setup do
    @product = Product.find(82)
  end

  test "adding brew rpm name prefixes" do
    assert @product.brew_rpm_name_prefixes.empty?
    @product.add_brew_rpm_name_prefix('foo', 'bar')
    assert_equal 2, @product.brew_rpm_name_prefixes.count
    assert @product.brew_rpm_name_prefix_strings.include?('foo')
    assert @product.brew_rpm_name_prefix_strings.include?('bar')
  end

  test "strip prefix from name" do
    prefix = BrewRpmNamePrefix.new(:product=>@product, :text=>'ruby193')

    assert_equal "blah",             prefix.stripped_from("ruby193-blah")
    assert_equal "ruby193blah",      prefix.stripped_from("ruby193blah")       # dash separator is required
    assert_equal "dev-ruby193-blah", prefix.stripped_from("dev-ruby193-blah")  # must be at start

    assert prefix.matches("ruby193-blah")
    refute prefix.matches("ruby193blah")
    refute prefix.matches("dev-ruby193-blah")
  end

  test "strip using list of prefixes" do
    @product.add_brew_rpm_name_prefix('aaa', 'bbb')
    assert_equal ['aaa', 'bbb'], @product.brew_rpm_name_prefix_strings

    assert_equal "foo", BrewRpmNamePrefix.strip_using_list_of_prefixes(@product.brew_rpm_name_prefixes, "aaa-foo")
    assert_equal "foo", BrewRpmNamePrefix.strip_using_list_of_prefixes(@product.brew_rpm_name_prefixes, "bbb-foo")

    # Only remove one (be defensive against weird edge cases)
    assert_equal "bbb-foo", BrewRpmNamePrefix.strip_using_list_of_prefixes(@product.brew_rpm_name_prefixes, "aaa-bbb-foo")
  end

end
