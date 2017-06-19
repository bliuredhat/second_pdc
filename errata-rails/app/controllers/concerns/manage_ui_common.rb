module ManageUICommon
  extend ActiveSupport::Concern

  include CurrentUser

  included do
    before_filter :no_h1_page_title
    before_filter :set_current_user_ivar
    before_filter :prevent_unauthorized_post
    before_filter :prevent_unauthorized_actions
    before_filter :include_stylesheets
    before_filter :include_javascripts

    helper_method :can_edit_mgmt_items?
    helper_method :can_edit_cpe?
  end

  #
  # For simple logging of attribute changes to objects
  #
  # Notes:
  #   - This is a quick/dirty approach to logging attribute changes
  #   - Might be a better way to do it
  #
  def log_attr_changes(obj)
    pre_update_attrs = obj.attributes.clone
    yield obj
    ADMIN_AUDIT_LOG.info([
      current_user.try(:login_name),
      "#{obj.class.name}<#{obj.id}>",
      "new:#{Hash[obj.attributes.select{|k, v| pre_update_attrs[k] != v}].inspect}",
      "old:#{Hash[pre_update_attrs.select{|k, v| obj.attributes[k] != v}].inspect}",
    ].compact.join(' '))
  end

  private

  def can_edit_mgmt_items?
    current_user.can_edit_admin_objects?
  end

  def can_edit_cpe?
    current_user.can_edit_cpe?
  end

  def no_h1_page_title
    @_no_auto_title = true
  end

  def prevent_unauthorized_post
    redirect_to_error!("Not permitted.", :unauthorized) if request.post? && !can_edit_mgmt_items?
  end

  def prevent_unauthorized_actions
    redirect_to_error!("Not permitted.", :unauthorized) if %w[update create new edit].include?(params[:action]) && !can_edit_mgmt_items?
  end

  def include_javascripts
    extra_javascript 'mgmt-ui', 'clickable_row', 'mgmt_object_navtab_helper'
  end

  def include_stylesheets
    extra_stylesheet 'mgmt-ui'
  end

end
