class UserController < ApplicationController
  include SharedApi::Users
  include SharedApi::SearchByNameLike

  before_filter :admin_restricted, :set_index_nav, :except => [:my_requests, :my_errata, :update_products, :assigned_errata, :preferences, :show_roles, :update_preferences, :users_by_role]
  before_filter :set_user, :only => [:my_requests, :my_errata, :preferences, :update_preferences, :show_roles]

  around_filter :with_error_handling, :only => [:edit, :update, :add_user, :create, :new, :show]
  before_filter :find_by_id_param, :only => [:edit, :update, :show]
  before_filter :sanitize_user_params, :only => [:add_user, :create, :edit, :update]

  # Readonly users can update their preferences and see their roles.
  skip_before_filter :readonly_restricted, :only => [:preferences, :update_preferences, :show_roles]

  verify :method => :post, :only => [:update_preferences, :add_user, :edit]

  def new
    set_page_title "Create new user"
    login_name = params[:login_name]
    @user = User.new
    if login_name.present?
      unless (record = find_user_by_id_or_name(login_name)).nil?
        raise ActiveRecord::RecordInvalid.new(record),
          "User with #{login_name} already exists in Errata Tool."
      end

      @user.login_name = login_name
      @userinfo = find_with_finger(login_name)
      @maybe_machine_user = @userinfo.nil?
      unless @maybe_machine_user
        @user.login_name = @userinfo[:login_name]
        @user.realname = @userinfo[:realname]
      end
    end

    respond_to do |format|
      format.js { render :action => :new }
      format.html { render :action => :new }
    end
  end

  def create
    create_new_user
    respond_to do |format|
      format.js { render :action => :new }
      format.any { head :ok }
    end
  end

  def assigned_errata
    return unless get_user
    @assigned_errata = []
    @assigned_errata.concat(@user.assigned_errata.active) if(@user.in_role?('qa'))
    @assigned_errata.concat(@user.devel_errata.active) if(@user.in_role?('devel'))

    set_page_title 'Assigned Advisories'
  end

  # alias for create for backward compatibility
  def add_user
    create
  end

  # alias for update for backward compatibility
  def edit
    update
  end

  #
  # This updates a user's roles and their enabled status
  # which are modified using checkboxes on the show action.
  # form.
  #
  # When it's done it sets a flash notice and redirect
  # back there. It also emails the user who's roles were
  # changed, cc-ing the person who did the changing.
  #
  def update
    set_user_details
    respond_to do |format|
      format.js { render :action => :new }
      format.any { head :ok }
    end
  end

  # Redirect for old links
  def edit_user
    redirect_to :action => :show, :id => params[:id]
  end

  def show
    @maybe_machine_user = find_with_finger(@user.login_name).nil?
    respond_to do |format|
      format.html do
        set_page_title "Edit #{@user.realname} (#{@user.login_name})"
        render :action => :new
      end
      format.json { render "api/v1/user/show" }
      format.text do
        txt = "Enabled: " if @user.enabled?
        txt = "Disabled: " unless @user.enabled?
        txt += "#{@user.realname} (#{@user.login_name}) is in roles: "
        txt += @user.roles.collect { |r| r.name }.join(', ')
        render :text => txt
      end
    end
  end

  def find_user
    unless request.post?
      redirect_to :action => :index
      return
    end

    id_or_name = params[:user].try(:[], :login_name) || params[:id]

    if id_or_name.nil?
      redirect_to_error!("No user provided")
      return
    end

    unless (@user = find_user_by_id_or_name(id_or_name))
      if @userinfo = find_with_finger(id_or_name)
        flash_message :alert,
          ERB::Util::html_escape(
            "#{@userinfo[:realname]} < #{@userinfo[:login_name]} > does not " +\
            "currently have an account in Errata Tool. Do you want to create an " +\
            "account for this user?")
        redirect_to :action => :new, :login_name => id_or_name
      else
        flash_message :error, "No such user #{id_or_name}."
        redirect_to :action => :index
      end
      return
    end

    redirect_to :action => :show, :id => @user
  end

  def index
    set_page_title 'Find Users'
  end

  def my_errata
    set_page_title "Advisories for #{@user.realname}"

    @errata_list = Errata.paginate(:page => params[:page],
                                   :conditions => ['is_valid = 1 and reporter_id = ?', @user],
                                   :order => 'errata_main.id desc',
                                   :include => [:product,:reporter,:release]
                                   )
  end

  def preferences
    @system_filters = SystemErrataFilter.in_display_order
    @user_filters   = UserErrataFilter.for_user(@user).order('name ASC')
    set_page_title 'Preferences'
  end

  def show_roles
    set_page_title "Roles for #{@user.login_name}"
  end

  def my_requests
    if current_user.in_role?('qa')
      redirect_to :controller => :qe, :action => :my_requests
    else
      redirect_to :controller => :devel, :action => :my_requests
    end
  end

  def list_users
    respond_to do |format|
      format.html do
        set_page_title "All Users"
        @users = User.paginate :page => params[:page], :per_page => 500, :order => 'login_name', :include => [:roles]
        @current_user = current_user
      end
      format.json do
        respond_with(User.includes(:roles).all)
      end
    end
  end

  def users_by_role
    @role = Role.find(params[:id]) if params[:id]
    @role = Role.find_by_name('qa') unless @role
    set_page_title "Users by Role"
    @users = @role.users.enabled.includes(:roles)
    @current_user = current_user
    @secondary_nav = get_role_nav(@role)
  end

  def search_by_name_like
    _search_by_name_like(
      :where => 'login_name like ?',
      :order => 'login_name',
      :map => lambda {|u| { 'name' => u.login_name,'realname' => u.realname }}
    )
  end

  def update_preferences
    #
    # The to_hash is so we don't serialize as HashWithIndifferenceAccess. Though
    # maybe that wouldn't matter much, not sure...
    #
    # The symbolize_keys is because I was seeing binary encoded hash keys in the yaml.
    # It think it is something to do with char encoding, eg yaml doesn't know what the
    # encoding is for a hash key string so doesn't assume it is ascii. If you symbolize_keys
    # then the you get nice readable yaml. Note, the binary hex hash keys still worked perfectly,
    # just weren't as readable in the database. (I saw this on my local workstation with
    # ruby 1.9, so might be different in 1.8).
    #
    User.current_user.update_attribute(:preferences, params[:user][:preferences].to_hash.symbolize_keys)

    flash_message :notice, "Preferences updated"
    redirect_to :action => :preferences
  end

  private

  def with_error_handling
    begin
      yield
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, ArgumentError => error
      @error = error
      @error_message = error.message
      respond_to do |format|
        format.js { render :action => :new }
        format.html { render :file => 'errata/error_message', :status => :unprocessable_entity }
        format.any { head :unprocessable_entity }
      end
    end
  end

  def sanitize_user_params
    raise ArgumentError, "No user data is provided." if params[:user].nil?

    @user_params = params[:user]
    if @user_params[:user_organization_id].present?
      org_id = @user_params[:user_organization_id]
      @user_params[:organization] = UserOrganization.find(org_id)
    end

    if @user_params[:roles].present?
      @user_params[:roles] = Role.find(:all, :conditions => ['name in (?)', @user_params[:roles]], :order => 'name ASC')
    end
  end

  def find_by_id_param
    id_or_name = params[:id]
    if (@user = find_user_by_id_or_name(id_or_name)).nil?
      raise ActiveRecord::RecordNotFound.new("No such user: #{id_or_name}")
    end
  end

  def get_user
    id = params[:id]
    begin
      if id =~ /^[0-9]+$/
        @user = User.find(params[:id])
      elsif id =~ /^[a-z]+$/
        @user = User.find_by_name(id)
      end
    rescue => e
      redirect_to_error!(e.to_s)
      return false
    end
    return true if @user

    redirect_to_error!("No such user: #{id}")
    return false
  end

  def get_role_nav(current_role)
    navlinks = []

    roles = Role.find(:all)
    roles.each do |r|
      role_link = { :name => r.long_title_name, :controller => :user, :action => :users_by_role, :id => r.id }
      role_link[:selected] = true if r == current_role
      navlinks << role_link
    end

    return navlinks
  end


  def get_secondary_nav
    nav = []
    nav << { :name => 'Find User', :controller => :user, :action => :index}
    nav << { :name => 'Create User', :controller => :user, :action => :new}
    nav << { :name => 'All Users', :controller => :user, :action => :list_users}
    nav << { :name => 'Users By Role', :controller => :user, :action => :users_by_role}

    return nav
  end

  def set_user
    if Rails.env.development? && params[:id]
      user_id = params[:id]
      @user = User.find(user_id)
    else
      @user = current_user
    end
  end
end
