class CarbonCopiesController < ApplicationController
  include ReplaceHtml
  respond_to :js
  before_filter :find_errata

  def add_to_cc_list
    user = User.find_by_name(params[:email])
    unless user
      update_flash_notice_message("Could not find user #{params[:email]}", :type=>:error)
      return
    end
    unless user.enabled? && user.in_role?('errata')
      update_flash_notice_message("User is not enabled: #{params[:email]}", :type=>:error)
      return
    end
    if @errata.cc_list.where(:who_id => user).exists?
      update_flash_notice_message("User already added to cc list", :type=>:error, :do_after=>js_clear('email'))
      return
    end
    cc = CarbonCopy.create(:errata => @errata, :who => user)
    new_html = partial_to_string 'errata/cc_edit', :object => cc
    render_js js_for_append('errata_cc_list', new_html) + js_clear('email')
  end

  def remove_from_cc_list
    @errata.cc_list.where(:who_id => params[:user_id]).delete_all
    render_js js_remove("cc_#{params[:user_id]}")
  end
end
