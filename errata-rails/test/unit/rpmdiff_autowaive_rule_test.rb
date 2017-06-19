require 'test_helper'

class RpmdiffAutowaiveRuleTest < ActiveSupport::TestCase

  test 'autowaive rule created by dev' do
    with_current_user(devel_user) do
      rule = rpmdiff_autowaive_rule
      rule.update_attributes(:active => true)
      assert rule.valid?
    end
  end

  test 'active autowaive rule created by admin valid' do
    with_current_user(admin_user) do
      rule = rpmdiff_autowaive_rule(:active => true)
      assert_valid rule
    end
  end

  test 'autowaive rule can not be created and activated without mandatory fields' do
    with_current_user(admin_user) do
      rule = RpmdiffAutowaiveRule.new
      data = {
        "score"=>"-1",
        "active"=>"1",
        "subpackage"=>"",
        "content_pattern"=>"",
        "reason"=>"",
        "test_id"=>"1",
        "product_version_ids"=>[],
        "package_name"=>""
      }
      rule.update_attributes(data)

      refute rule.valid?

      [:package_name, :content_pattern, :reason, :product_versions].each do |attr|
        assert rule.errors.full_messages.include?("#{attr.to_s.humanize} can't be blank")
      end
    end
  end

  test 'active autowaive rule can not be updated even just production versions is blank' do
    with_current_user(admin_user) do
      rpmdiff_autowaive_rule(
        :active => true,
        :subpackage => "test",
        :content_pattern => "test",
        :reason => "test",
        :test_id => "1",
        :product_version_ids => ["1"],
        :package_name => "rhev-hypervisor"
      )

      rule =  RpmdiffAutowaiveRule.last
      assert_valid rule
      data1 = {"product_version_ids"=>[]}
      rule.update_attributes(data1)

      refute rule.valid?

      [:product_versions].each do |attr|
        assert rule.errors.full_messages.include?("#{attr.to_s.humanize} can't be blank")
      end
    end
  end

  #
  # This is to avoid triggering validation methods when simply reading
  # the record.
  #
  test 'active autowaive rule valid for devel user' do
    with_current_user(admin_user) do
      rule = rpmdiff_autowaive_rule(:active => true)
      with_current_user(devel_user) do
        assert_valid rule
      end
    end
  end

  test 'autowaive rule validates package name successfully' do
    invalid_package_name = 'nonexisting_package'
    assert_nil Package.find_by_name(invalid_package_name)

    rule = rpmdiff_autowaive_rule
    rule.update_attributes(:package_name => invalid_package_name)
    refute rule.valid?
    assert_match %r{\bis not a valid package}, rule.errors.full_messages.join
  end

  test 'try to activate security related autowaive rule' do
    with_current_user(devel_user) do
      rule = rpmdiff_autowaive_rule
      rule.update_attributes(:created_from_rpmdiff_result_detail_id => '462914')
      assert rule.valid?
      refute rule.can_activate?

      with_current_user(secalert_user) do
        assert rule.can_activate?
      end
      with_current_user(releng_user) do
        refute rule.can_activate?
      end
    end
  end

  test 'try to activate release related autowaive rule' do
    with_current_user(devel_user) do
      rule = rpmdiff_autowaive_rule
      rule.update_attributes(:created_from_rpmdiff_result_detail_id => '462915')
      assert rule.valid?
      refute rule.can_activate?

      with_current_user(secalert_user) do
        refute rule.can_activate?
      end
      with_current_user(releng_user) do
        assert rule.can_activate?
      end
    end
  end

  test 'try to activate normal autowaive rule' do
    with_current_user(devel_user) do
      rule = rpmdiff_autowaive_rule
      assert rule.valid?
      assert rule.can_activate?
    end
  end


  test 'content to regexp' do
    # in ruby, for single-quoted strings, two consecutive backslashes are
    # replaced by a single backslash

    # case 1: no backslash
    content_pattern_test 'hi there {(please)}', 'hi there \{\(please\)\}'

    # case 2: one backslash
    content_pattern_test 'hi\ there', 'hi\\\\ there'

    # case 3: three backslashes
    content_pattern_test 'hi\\\ there', 'hi\\\\\\\\ there'

    # case 4: nil
    assert RpmdiffAutowaiveRule.content_to_regexp(nil).nil?
  end

  def content_pattern_test(input, expected)
    actual = RpmdiffAutowaiveRule.content_to_regexp(input)
    assert_equal expected, actual
    assert Regexp.new(actual).match(input)
  end

end
