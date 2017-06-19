class TcmsController < ApplicationController
  include ReplaceHtml
  verify :method => :post
  before_filter :find_errata

  def add_test_plan
    plan_id_text = params[:plan][:id].to_s.strip
    plan_id = plan_id_text.to_i
    max_plan_id = 2**31 - 1
    if plan_id.to_s != plan_id_text || plan_id < 1 || plan_id > max_plan_id
      return update_flash_notice_message("Please enter an integer plan id between 1 and #{max_plan_id}", :type=>:error)
    end
    if NitrateTestPlan.exists?(['id = ? and errata_id = ?', plan_id, @errata.id])
      return update_flash_notice_message("Test plan #{plan_id} already added to this advisory", :type=>:error)
    end
    if NitrateTestPlan.exists?(plan_id)
      return update_flash_notice_message("Test plan #{plan_id} already associated with #{NitrateTestPlan.find(plan_id).errata.fulladvisory}", :type=>:error)
    end
    plan = NitrateTestPlan.new(:errata => @errata)
    plan.id = plan_id
    plan.save!
    @errata.comments.create(:text => "Added Nitrate test plan #{plan_id}", :who => current_user)

    js = "$('#plan_id').val('');"
    js += "$('#no_test_plans').hide();"

    new_html = partial_to_string 'test_plan', :object => plan
    js += js_for_append('nitrate_test_plans', new_html)
    render_js js
  end

  def remove_test_plan
    plan_id = params[:plan_id]
    # Considered adding a deleted flag to the record and using that
    # to mark a plan as deleted. However, the plan id is used as a
    # primary key, so it would mean that a deleted plan could not be
    # re-added to an advisory. So I'm just going to remove the record.
    # (It's a bit nasty but should be okay in this case).
    NitrateTestPlan.destroy(plan_id.to_i)
    @errata.comments.create(:text => "Removed Nitrate test plan #{plan_id}", :who => current_user)
    js = "$('#test_plan_#{plan_id}').remove();"
    js += "$('#no_test_plans').show();" if @errata.nitrate_test_plans.empty?
    render_js js
  end
end
