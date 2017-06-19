module WorkflowRulesHelper
  include ActionView::Helpers::OutputSafetyHelper

  def guard_message_and_icon(message, icon_type)
    "<span class='step-status step-status-#{icon_type} with-border'>#{status_icon(icon_type)}</span> #{h(message)}".html_safe
  end

  def rule_set_locked_text(rule_set)
    rule_set.is_locked? ? icon_btn_text("Yes", :lock, :opacity=>0.8) : '<span class="superlight">No</span>'.html_safe
  end

  def rule_set_product_list(rule_set)
    if rule_set.products.any?
      safe_join(@rule_set.products.sort_by(&:short_name).map { |p| link_to p.short_name, url_for(p), :title=>p.name }, ", ")
    else
      '<span class="superlight">None</span>'.html_safe
    end
  end

  def rule_set_release_list(rule_set)
    if rule_set.releases.any?
      safe_join(rule_set.releases.sort_by(&:name).map { |r| link_to(r.name, :action => :show, :controller => :release, :id => r, :title=>r.name) }, ", ")
    else
      '<span class="superlight">None</span>'.html_safe
    end
  end

  # Leave off secalert and admin since they can do any transition
  def show_roles_list(guard)
    safe_join(guard.state_transition.roles.reject { |r| %w[secalert admin].include?(r) }.map(&:capitalize), ", ")
  end
end
