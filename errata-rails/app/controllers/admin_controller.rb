class AdminController < ApplicationController
  respond_to :html, :json
  include CurrentUser
  before_filter :admin_restricted, :except=>:optional_layered_map
  before_filter :super_user_restricted, :only=>:settings
  before_filter :set_current_user_ivar

  def index
  end

  def settings
    set_page_title "Settings"
    @settings_keys = (Settings.all.keys + Settings.defaults.keys).sort.uniq
  end
end
