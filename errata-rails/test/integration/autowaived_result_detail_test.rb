require 'test_helper'

class AutowaivedResultDetailTest < ActionDispatch::IntegrationTest

  setup do
    @result = RpmdiffResult.find(760561)

    @autowaive_rule1 = rpmdiff_autowaive_rule
    @rule_id = @autowaive_rule1.autowaive_rule_id
    @rule_url = "/rpmdiff/show_autowaive_rule/#{@rule_id}"

    @detail_ids = [462912, 462913]
    waive_details_by_rule(@detail_ids, @autowaive_rule1)

    @autowaive_rule2 = rpmdiff_autowaive_rule
  end

  test 'show link to matched autowaiving rule when a result detail is waived' do
    auth_as qa_user

    get "/rpmdiff/show/#{@result.run_id}?result_id=#{@result.result_id}"
    assert_response :success

    @detail_ids.each do |detail_id|
      # there must be row for each waiver
      assert_select "tr#rpmdiff_detail_#{detail_id}" do
        # must contain the text WAIVED
        assert_select 'td', :text => /WAIVED/
        # must display the rule used to create the waiver
        assert_select 'td.tiny.compact', :text => /Autowaived by rule:/ do
          assert_select "a[href=#{@rule_url}]", :text => @rule_id
        end
      end
    end
  end

end
