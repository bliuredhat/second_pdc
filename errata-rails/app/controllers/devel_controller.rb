class DevelController < ApplicationController
  def index
    redirect_to :action => :my_requests
  end
  
  def my_requests
    @user = current_user
    @button_bar_partial = 'errata/new_advisory_button'
    set_page_title "Active Advisories for #{@user.realname}"

    assigned_errata = @user.devel_errata.active
    assigned_errata.concat(@user.reported_errata.active)
    assigned_errata.uniq!

    @filed_bugs = []
    @assigned_errata = assigned_errata.map do |e|
      @filed_bugs.concat(e.filed_bugs)
      [e, e.status == State::NEW_FILES, @user]
    end

  end

end

