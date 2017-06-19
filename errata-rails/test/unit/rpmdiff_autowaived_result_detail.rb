require 'test_helper'

class RpmdiffAutowaivedResultDetailTest < ActiveSupport::TestCase

  setup do
    @autowaive_rule1 = rpmdiff_autowaive_rule
    @detail_ids = [462912, 462913]
    waive_details_by_rule(@detail_ids, @autowaive_rule1)

    @autowaive_rule2 = rpmdiff_autowaive_rule
  end

  test 'waived result detail should have a matched rule' do
    detail = RpmdiffResultDetail.find(462911)
    assert_nil detail.matched_rule

    detail = RpmdiffResultDetail.find(462912)
    assert_not_nil detail.matched_rule
    assert_equal detail.matched_rule.autowaive_rule_id, @autowaive_rule1.autowaive_rule_id
  end

  test 'an autowaiving rule can waive multiple details' do
    assert_equal 0, @autowaive_rule2.result_details.length

    assert_equal 2, @autowaive_rule1.result_details.length

    detail_ids = @autowaive_rule1.result_details.collect {|detail| detail.result_detail_id}
    detail_ids.sort!
    assert_equal @detail_ids, detail_ids
  end

end
