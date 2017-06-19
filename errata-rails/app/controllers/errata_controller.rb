require 'diffstring'
require 'optional'
require 'jbuilder'

# :api-category: Legacy
class ErrataController < ApplicationController
  include Optional, ReplaceHtml

  skip_before_filter :readonly_restricted,
  :only => [:errata_error,
            :errata_for_release,
            :find,
            :index,
            :delete_filter,
            :filter_permalink,
            :show_xml,
            :show_text,
            :view,
            :details,
            :content,
            :cpe_list,
            :ajax_quick_action_menu_links,
            :container, :container_content, :modal_container_text,
            # (Ensure readonly user can get to these redirects)
            :show, :info, :stateview, :list, :list_errata,
            ]

  verify :method => :post,
  :only => [:add_comment,
            :add_to_cc_list,
            :add_test_plan,
            :assign_errata_to_me,
            :delete,
            :preview,
            :remove_from_cc_list,
            :save_errata,
            :update_errata,
            :change_docs_reviewer,
            :security_approve,
            :security_disapprove,
            :request_security_approval,
            ]

  before_filter :find_errata,
  :except => [
              :errata_error,
              :errata_for_release,
              :edit,
              :find,
              :index,
              :my_requests,
              :new,
              :new_errata,
              :new_pdc_errata,
              :new_choose,
              :preview,
              :set_form_for_product,
              :save_errata,
              :unassigned,
              :throw_exception,
              :test_flash_notices,
              :delete_filter,
              :filter_permalink,
              :update_release_ship_date,
              # (These are just redirects)
              :list, :list_errata,
              ]

  before_filter :set_defaults_for_create, :only => [
    :new_errata,
    :clone_errata,
  ]

  before_filter :set_default_for_pdc_create, :only => [
    :new_pdc_errata,
  ]

  before_filter :set_advisory_form, :only => [
    :edit,
    :preview,
    :save_errata,
    :change_docs_reviewer,
    :security_approve,
    :security_disapprove,
    :request_security_approval,
    :edit_batch,
  ]
  before_filter :can_edit_advisory?, :only => [
    :edit,
    :preview,
    :save_errata,
    :security_approve,
    :security_disapprove,
    :request_security_approval,
  ]

  before_filter :reconcile_bugs_for_rhsa,
  :only => [:show_text,:show_xml]

  before_filter :set_index_nav, :only => [:test_results]

  before_filter :remind_user_of_unassigned_advisory, :only => [:view, :details]

  around_filter :with_validation_error_rendering, :only => [
    :index,
    :filter_permalink,
  ]

  respond_to :html, :json

  use_helper_method :is_valid_datetime

  # -----------------------------------
  # Redirects for removed methods
  #
  def _advisory_url_redir
    redirect_to :action => :view, :id => @errata.id
  end

  def _list_url_redir
    flash_message :alert, "URLs starting with '/errata/list_errata' or '/errata/list' are no longer functional. " +
      "Please update your bookmarks. (Click 'Modify' below to access filter parameters)."
    redirect_to :action => :index
  end

  def _new_errata
    extra_javascript 'advisory_edit_form'

    ap = {}
    ap[:package_owner_email] = current_user.login_name
    if current_user.organization && current_user.organization.manager
      ap[:manager_email] = current_user.organization.manager.login_name
    else
      logger.warn "User #{current_user.id} not found in the org chart. Using default manager"
      ap[:manager_email] = User.default_qa_user.login_name
    end
    ap[:solution] ||= @product.default_solution.text

    create_params = HashWithIndifferentAccess.new
    create_params[:advisory] = ap
    create_params[:product] = {:id => @product.id}
    create_params[:release] = {:id => @release.id}
    create_params[:is_pdc] = creating_pdc_advisory?
    @advisory = CreateAdvisoryForm.new(current_user, create_params)
  end

  def show;        _advisory_url_redir; end
  def info;        _advisory_url_redir; end
  def stateview;   _advisory_url_redir; end
  def list;        _list_url_redir;     end
  def list_errata; _list_url_redir;     end

  # (End redirects for removed methods)
  # -----------------------------------

  def add_comment
    @user = current_user
    comment_text = params[:comment]
    add_user_to_cc_list = (params[:add_cc].to_bool && !@errata.cc_users.include?(@user))

    comment = Comment.transaction do
      @errata.cc_list.create!(:who => @user) if add_user_to_cc_list
      @errata.comments.create!(:who => @user, :text => comment_text)
    end

    respond_to do |format|
      format.js do
        prepare_comment_opts
        content = partial_to_string  'errata/sections/state_comment', :object => comment
        js = js_for_after('state-comment-container', content) if @comments_newest_first
        js ||= js_for_before('state-comment-container', content)
        js += "$('#state_comment_field').val('');"
        # Reset comment char counter to zero (see charcount.js)
        js += "charCounter('state_comment_field', 4000, false);"
        if add_user_to_cc_list
          js += js_for_html(:cc_list_text, @errata.cc_emails_short.join(', '))
          js += js_remove(:add_cc_container)
        end
        render :js => js
      end
      format.json { render :json => comment.to_json }
    end
  end

  # See view...
  def edit_depends_on
  end

  #
  # This method actually is used for both adding blocking advisory
  # and adding a dependent advisory.
  #
  # It uses the params[:action] to differentiate between the two.
  # See trickery comment below.
  #
  def add_blocking_advisory
    # Calling ajax_refresh_dependencies when nothing has changed will
    # needlessly refresh page content, but it doesn't matter too much..

    begin
      blocker = Errata.find_by_advisory(params[:advisory_id])
    rescue BadErrataID => e
      ajax_refresh_dependencies("Can't find advisory for '#{params[:advisory_id]}'.")
      return
    end

    if blocker == @errata
      ajax_refresh_dependencies("An advisory can't be its own dependency.")
      return

    elsif params[:action] == 'add_blocking_advisory' && !@errata.blocking_errata.exists?(blocker)
      # Add a new blocking advisory
      @errata.blocking_errata << blocker

    elsif params[:action] == 'add_dependent_advisory' && !@errata.dependent_errata.exists?(blocker)
      # Add a new dependent advisory
      @errata.dependent_errata << blocker

    else
      # Could get pointless dupe comments if you don't return here..
      ajax_refresh_dependencies("Advisory already listed")
      return
    end

    # Going to use this to indicate if the new dependency is disallowed
    # (It will also contain a message about the problem to show to user..)
    fail_notice = nil

    # Check for and prevent circular dependencies and new dependency that would
    # already be broken.
    #
    # It would probably be better to do these are validation in the models but going
    # to do them here for a quick/dirty solution).
    #
    # (Note: We don't lock, so two co-operating users with very good timing might be able
    # to add a circular dependency. Could possibly use a db transaction, then a rollback
    # but nevermind that for now..)
    #
    if @errata.dependency_graph.is_circular?
      fail_notice = "Can't add #{blocker.advisory_name} here because it would create a circular dependency."

    elsif @errata.should_have_blocked.any?
      # Don't allow blocking something that is already shipped or push ready..
      fail_notice = "Can't add dependency for #{blocker.advisory_name} because " +
                     "#{@errata.should_have_blocked.map(&:advisory_name).join(', ')} is already SHIPPED_LIVE or PUSH_READY."

    elsif @errata.should_have_been_blocked_by.any?
      # Don't allow blocker if we are already shipped or push ready..
      # Actually this ought to never happen since you can't edit the dependencies when in PUSH_READY or SHIPPED_LIVE..
      fail_notice = "Can't add dependency for #{blocker.advisory_name} because " +
                     "#{@errata.should_have_blocked.map(&:advisory_name).join(', ')} would block this advisory."
    end

    if fail_notice
      # Remove the dependency we just added
      if params[:action] == 'add_blocking_advisory'
        @errata.blocking_errata.delete(blocker)
      else
        @errata.dependent_errata.delete(blocker)
      end
    else
      # Keeping the new dependency, so now add a comment
      if params[:action] == 'add_blocking_advisory'
        parent = @errata
        child = blocker
      else
        parent = blocker
        child = @errata
      end
      parent.comments.create(:who => current_user, :text => "Dependency added. This advisory now depends on #{child.advisory_name}")
      child.comments.create(:who => current_user, :text => "Dependency added. This advisory now blocks #{parent.advisory_name}")
    end

    # Refresh
    @errata = Errata.find(@errata.id)
    ajax_refresh_dependencies(fail_notice)
  end

  def remove_blocking_advisory
    blocker = Errata.find(params[:blocker_id])
    if params[:action] == 'remove_blocking_advisory'
      @errata.blocking_errata.delete(blocker)
      parent = @errata
      child = blocker
    else
      @errata.dependent_errata.delete(blocker)
      parent = blocker
      child = @errata
    end
    parent.comments.create(:who => current_user, :text => "Dependency removed. This advisory no longer depends on #{child.advisory_name}")
    child.comments.create(:who => current_user, :text => "Dependency removed. This advisory no longer blocks #{parent.advisory_name}")
    ajax_refresh_dependencies
  end

  # Warning, trickery ahead..
  def add_dependent_advisory;    add_blocking_advisory;    end
  def remove_dependent_advisory; remove_blocking_advisory; end

  private #<---
  def ajax_refresh_dependencies(notice = '')
    if notice.blank?
      js = js_for_template('dependency_graph', 'dependency_graph')
      js += js_for_template('depends_on_errata', 'dependency_edit', :locals => { :mode => :depends_on })
      js += js_for_template('blocks_errata', 'dependency_edit', :locals => { :mode => :blocks })

    else
      js = flash_notice_js(notice, :type => :error)
      js += js_clear(params[:action] + '_field')
    end
    render :js => js
  end
  public #--->

  def drop_errata
    return unless can_drop_advisory?
    set_page_title "Drop Advisory #{@errata.advisory_name}"
    return unless request.post?
    @errata.change_state!(State::DROPPED_NO_SHIP, current_user, params[:reason])
    redirect_to :action => :view, :id => @errata
  end

  # An error has occurred somewhere
  # No controller logic, only here to display the page
  def errata_error
  end

  #
  # Fetch a list of advisories belonging to a release.
  #
  # :api-url: /release/{release_id}/advisories.json
  # :api-method: GET
  #
  # `release_id` could be an integer ID (for example, `554`) or a release
  # url name (for example `ceph_2_0`). To determine a release url name, replace
  # all period (`.`) and dash (`-`) characters with underscores (`_`), and
  # lowercase all alpha characters. The value should be url-encoded (ie,
  # replace space characters " " with `%20`).
  #
  # Example response:
  #
  # ```` JavaScript
  # [
  #  {
  #    "qe_owner":"lfuka@redhat.com",
  #    "id":19332,
  #    "advisory_name":"RHEA-2015:0944",
  #    "release_date":null,
  #    "status":"SHIPPED_LIVE",
  #    "product":"Red Hat JBoss Web Server",
  #    "qe_group":"Middleware QE - Tomcat",
  #    "release":"RHEL-7-JWS-3.0",
  #    "status_time":"May 05, 2015 18:55",
  #    "synopsis":"Red Hat JBoss Web Server 3.0.0 enhancement update"
  #  },
  #  {
  #    "qe_owner":"jstourac@redhat.com",
  #    "id":20503,
  #    "advisory_name":"RHEA-2015:20503",
  #    "release_date":null,
  #    "status":"NEW_FILES",
  #    "product":"Red Hat JBoss Web Server",
  #    "qe_group":"Middleware QE - Tomcat",
  #    "release":"RHEL-7-JWS-3.0",
  #    "status_time":"July 29, 2015 17:45",
  #    "synopsis":"Red Hat JBoss Web Server 3.0.1 enhancement update"
  #  }
  # ]
  # ````
  def errata_for_release
    unless params[:id]
      redirect_to_error!("No Release id given.")
      return
    end

    if params[:id] =~ /^[0-9]+$/
      @release = Release.find(params[:id])
    else
      @release = Release.find_by_url_name(params[:id])
    end
    unless @release
      redirect_to_error!("Cannot find release with name #{params[:id]}.")
      return
    end

    @errata_list = @release.errata.find(:all,
                                        :include => [:bugs, :assigned_to, :quality_responsibility],
                                        :order => 'status desc, status_updated_at asc')

    respond_to do |format|
      format.html do
        @bug_count = 0
        @verified_count = 0
        @unassigned_count = 0
        @errata_list.each do |e|
          @bug_count = @bug_count + e.bugs.length
          @verified_count = @verified_count + e.verified_bugs.length
          @unassigned_count = @unassigned_count + 1 if e.unassigned?
        end
      end
      format.json do
        render :layout => false,
        :json => advisory_list_to_json(@errata_list)
      end
    end
  end

  def edit
    extra_javascript 'advisory_edit_form'
    @product = @advisory.product
    set_releases_for @product
    @products = Product.active_products
    if advisory_is_pdc?
      @is_pdc = true
      @products = @products.supports_pdc
    end
    @release = @advisory.release
    set_page_title 'Edit Advisory ' + @advisory.fulladvisory
  end

  def edit_batch
    @batches = @errata.release.batches.unreleased.unlocked
    @batch = @errata.batch

    # Ensure current @batch is included, as it might be locked
    @batches << @batch if @batch && !@batches.include?(@batch)
    return unless request.post?

    attrs = {}
    attrs[:batch_id] = params[:batch][:id] if params[:batch]
    attrs[:is_batch_blocker] = params[:errata][:is_batch_blocker] if params[:errata]
    if @errata.update_attributes(attrs)
      flash_message :notice, 'Batch details successfully updated.'
      redirect_to :action => :details, :id => @errata
    else
      flash_message :error, "Unable to update: #{@errata.errors.full_messages.join(',')}"
      render :action => :edit_batch, :id => @errata
    end

  end

  # Used to be called `edit_how_to_test`
  def edit_notes
    @content = @errata.content
    return unless request.post?

    if @content.update_attributes(params[:content])
      @errata.comments.create(:who => current_user, :text => "Notes updated.")
      flash_message :notice, 'Notes successfully updated.'
      redirect_to :action => :details, :id => @content.errata
    else
      render :action => :edit_notes
    end

  end

  # This is now obsolete and deprecated. I don't think it is used anywhere
  # but let's keep this redirect just in case it is. Will also help in case
  # someone has an old bookmark with this url. See Bug 957586.
  def find
    redirect_to :action => 'index', :search => params[:advisory].try(:fetch, :name)
  end

  def my_requests
    if params[:id]
      @user = User.find(params[:id])
    else
      @user = current_user
    end

    @assigned_errata = []
    @attention_required = []

    active_errata = []
    attention_state = nil
    if(@user.in_role?('qa'))
      active_errata = @user.assigned_errata.active
      attention_state = State::QE
    elsif(@user.in_role?('devel'))
      active_errata = @user.devel_errata.active
      attention_state = State::NEW_FILES
    end

    active_errata.each do |e|
      if e.status == attention_state
        @attention_required << e
      else
        @assigned_errata << e
      end
    end

    set_page_title 'My Errata'
  end

  ### Interface routines used to display various pages ###
  def new
    # We used to have a separate page here to choose between cloning or creating
    # an advisory.  Now it's all merged into new_errata.
    redirect_to :action => :new_errata
  end

  def new_errata
    _new_errata
  end

  def new_pdc_errata
    unless @product && @release
      redirect_to_error!("Can not find related product and/or release")
      return
    end
    @is_pdc = true
    _new_errata
    render :template => 'errata/new_errata'
  end

  def clone_errata
    @user = User.current_user
    @cloned_errata = @errata
    create_params = AdvisoryForm.clone_errata_by_params(@user, :id => @errata.id)
    @advisory = CreateAdvisoryForm.new(@user, create_params)

    # (If the release is no longer current that's okay, it just means
    # there won't be a selected release in the drop down select).
    set_releases_for @advisory.product
    @release = @advisory.release

    render_js js_for_template(:edit_form, 'edit_form', :object => @advisory)
  end

  def preview
    if @advisory.valid?
      @cve_problems = @advisory.cve_problems.values.flatten
      @spelling_errors = { }
      @url_issues = validate_urls(@advisory.content.reference.split)
      @spelling_errors = { }
      %w(synopsis topic description).each do |key|
        errors = check_spelling @advisory.send(key)
        next if errors.empty?
        @spelling_errors[key] = errors
      end
      @product = @advisory.product
      @release = @advisory.release
      unless @advisory.new_record?
        if ruleset_will_change?(Errata.find(@advisory.id), @release, @product)
          flash.now[:alert] = "Note: the advisory's workflow rule set will be changed due to the change of product or release."
        end
      end
    else
      extra_javascript 'advisory_edit_form'
      set_releases_for @advisory.product
      get_manager_and_package_owner
      @products = Product.active_products
      if advisory_is_pdc?
        @is_pdc = true
        @products = @products.supports_pdc
      end
      @release = Release.find(params[:release][:id]) if params[:release]

      if @advisory.new_record?
        render :action => :new_errata
      else
        set_page_title 'Edit Advisory ' + @advisory.fulladvisory
        render :action => :edit
      end
    end
  end

  def request_unfiled
  end

  # Combine rhts & tcms (for 2.3 ui demo)
  # (Untested, possibly doesn't work...)
  #
  def test_results
    extra_javascript 'test_results'
  end

  def save_errata
    was_new = @advisory.new_record?
    @advisory.save!
    redirect_to :action => (was_new ? 'view' : 'details'), :id => @advisory
  end

  def request_security_approval
    change_security_approved_to(false)
  end

  def security_approve
    change_security_approved_to(true)
  end

  def security_disapprove
    change_security_approved_to(nil)
  end

  def set_live_advisory_name
    return unless validate_user_roles('admin', 'secalert')
    return unless request.post?
    old = @errata.fulladvisory
    LiveAdvisoryName.set_live_advisory! @errata
    flash_message :notice, "Advisory name changed from #{old} to #{@errata.fulladvisory}"
    redirect_to :action => :view, :id => @errata
  end

  def close
    if @errata.closed?
      logger.debug "Set errata to reopen"
      @errata.closed = 0
      action = "reopened"
    else
      logger.debug "Set errata to close"
      @errata.closed = 1
      action = "closed"
    end

    logger.debug "Saving errata"
    @errata.save

    flash_message :notice, "Advisory #{@errata.shortadvisory} has been #{action}."
    redirect_to :action => :view, :id => @errata
  end

  def state_test
    @user = current_user
  end

  def other_xml
    respond_to do |format|
      format.xml
    end
  end

  def show_xml
    @user = current_user
    render :action => 'errata_xml', :layout => false, :content_type => 'text/xml'
  end

  def show_text
    render :action => 'errata_text', :layout => false, :content_type => 'text/plain'
  end

  def show_activity
    listItem,old_user,old_time = nil,nil,nil; @activity_list = []
    latest  = nil

    if params[:asc].to_bool then
      errata_sorted = @errata.activities.sort_by { |activity| activity[:created_at] }
    else
      errata_sorted = @errata.activities.sort_by { |activity| activity[:created_at] }.reverse
    end

     errata_sorted.each do |activity|
      if activity.who.id != old_user || activity.created_at != old_time
        @activity_list.push listItem if listItem
        listItem = {
          :user => activity.who.login_name,
          :created_at => activity.created_at.strftime("%Y-%m-%d %H:%M:%S"),
          :operations => []
        }
        old_user,old_time = activity.who.id,activity.created_at
      end
      latest = listItem[:operations].push({:what => activity.what, :removed => activity.removed, :added => activity.added})
    end
    @activity_list.push listItem if listItem
    set_page_title "QA Request Activity for " + @errata.shortadvisory + ' - ' + @errata.synopsis
  end

  # After a product has been selected on advisory create/edit form, fill in
  # certain form fields with appropriate values.
  def set_form_for_product
    @product = Product.find(params[:product][:id])
    rel = set_releases_for @product
    js = js_for_template(:release_list, 'release_list', :object => @releases)
    if rel.empty?
      js += js_hide(:submit_tag) + js_show(:warn_no_releases)
    else
      @release = @releases.first
      js += js_show(:submit_tag) + js_hide(:warn_no_releases)
    end

    new_solution = @product.try(:default_solution).try(:text)
    js += js_set_val('advisory_solution', new_solution)

    render_js js
  end

  #
  # When the user selects a new Advisory Release from the dropdown
  # when editing or creating an advisory, this will be used to display
  # the release date for that release (if there is one), next to the
  # drop down.
  #
  def update_release_ship_date
    release = Release.find(params[:release][:id])
    render_js js_for_html('release_ship_date_display', release.ship_date_display)
  end

  def text_only_channels
    unless @errata.text_only?
      flash_message :error, "Advisory is not tagged as text-only!"
      redirect_to :action => :view, :id => @errata
      return
    end
    if request.post?
      @errata.text_only_channel_list.set_channels_by_id(params[:channels])
      @errata.text_only_channel_list.set_cdn_repos_by_id(params[:cdnrepos])
      @errata.text_only_channel_list.save
      flash_message :notice, "Channels/Repositories updated"
      redirect_to :action => :view, :id => @errata
      return
    end
    set_page_title "RHN Channels/CDN Repos for Text Only Advisory #{@errata.advisory_name}"
    # Only binary CDN repos should be selectable for metadata
    @channels_and_repos = [
      @errata.active_channels_for_available_product_versions,
      @errata.active_cdn_repos_for_available_product_versions.select(&:is_binary_repo?)
    ].flatten
    @current = @errata.text_only_channel_list.get_all_channel_and_cdn_repos.map(&:name).to_set
  end

  def docker_cdn_repos
    unless @errata.status_is?(:NEW_FILES)
      flash_message :error, "Advisory must be in NEW_FILES state to change Metadata CDN Repos"
      redirect_to :action => :view, :id => @errata
      return
    end
    unless @errata.has_docker?
      flash_message :error, "Advisory does not contain docker images!"
      redirect_to :action => :view, :id => @errata
      return
    end
    if request.post?
      existing_ids = @errata.docker_metadata_repo_list.get_cdn_repos.map(&:id).sort
      new_ids = (params[:cdnrepos] || []).map(&:to_i).sort
      if existing_ids == new_ids
        flash_message :notice, "Advisory metadata CDN repositories have not been changed"
      else
        @errata.docker_metadata_repo_list.set_cdn_repos_by_id(new_ids)
        @errata.docker_metadata_repo_list.save!
        if new_ids.any?
          @errata.comments.create!(
            :who => @user,
            :text => "Advisory metadata CDN repositories set to: #{@errata.docker_metadata_repo_list.get_cdn_repos.map(&:name).join(', ')}"
          )
          flash_message :notice, "Advisory metadata CDN repositories updated"
        else
          @errata.comments.create!(
            :who => @user,
            :text => "Advisory metadata CDN repositories have been cleared"
          )
          flash_message :notice, "Advisory metadata CDN repositories have been cleared"
        end
      end
      redirect_to :action => :view, :id => @errata
      return
    end
    set_page_title "Metadata CDN Repositories for Advisory #{@errata.advisory_name}"
    if @errata.docker_metadata_repo_list.nil?
      @errata.docker_metadata_repo_list = DockerMetadataRepoList.create(:errata => @errata)
      @errata.save!
    end
    @channels_and_repos = @errata.active_cdn_repos_for_available_product_versions.select(&:is_binary_repo?)
    @current = @errata.docker_metadata_repo_list.get_cdn_repos.map(&:name).to_set
  end

  def unassigned
    redirect_to :controller => :qe, :action => :unassigned
  end

  #------------------------------------------------------------
  # TODO: These are clutter, should move them elsewhere or remove entirely

  #
  # For test purposes only...
  # Go to /errata/throw_exception to throw an exception
  #
  def throw_exception
    case params[:type]
    when 'no_user_access'
      render :file => 'shared/site_messages/no_user_access', :status => 403
    when 'no_kerberos'
      render :file => 'shared/site_messages/no_kerberos', :status => 401
    else
      raise 'BAD STUFF HAPPENED! :('
    end
  end

  def modal_related_advisories
    render :partial => "related_advisories_by_package"
  end

  def modal_change_state
    prepare_user_var
    prepare_state_transitions
    render :partial => "change_state_form"
  end

  def modal_change_owner
    prepare_qe_dropdowns
    render :partial => "change_owner_form"
  end

  def modal_change_docs_reviewer
    render :partial => 'docs/change_docs_reviewer_modal', :locals => { :errata => @errata, :back_to => params['back_to'] }
  end

  def ajax_quick_action_menu_links
    render :partial => 'quick_action_menu_links', :locals => { :errata => @errata }
  end

  #
  # For test purposes only...
  # Make sure flash notices work
  #
  def test_flash_notices
    set_page_title "Test Flash Notices"
    action = params[:action]
    mode = params[:mode]
    flash_type = params[:flash_type].try(:to_sym)

    text = case flash_type
    when :notice; "All is well."
    when :alert; "You should take a look at this."
    when :error; "Something went horribly wrong!"
    end

    case mode when 'normal'
      flash_message flash_type, text
      redirect_to :action=>action

    when 'redir'
      # redirect_to recognises :alert and :notice directly, but not :error
      flash_type == :error ?
        redirect_to({:action=>action}, :flash=>{flash_type=>text}) :
        redirect_to({:action=>action}, flash_type=>text)

    when 'ajax'
      update_flash_notice_message(text, :type=>flash_type)

    when 'nofade'
      update_flash_notice_message(text, :type=>flash_type, :nofade=>true)

    when 'html_test'
      # The message gets sanitized, but some tags are allowed
      flash_message :notice, '<div><p>para</p><ul><li>item1</li><li>item2</li></ul><b>bold</b> or <i>ital</i><script>BAD STUFF</script></div>'
      redirect_to :action=>action

    when 'multi'
      flash_message flash_type, "This is the first #{flash_type} message."
      flash_message flash_type, "Here is the second #{flash_type} message<br>over two lines"
      flash_message flash_type, text
      redirect_to :action=>action
    end
  end

  #------------------------------------------------------------
  #------------------------------------------------------------
  # This stuff was new for the 2.3 UI update.
  # (Moved from a/c/errrata_controller/new_ui_actions)

  #
  # Display a list of advisories (and filter options form)
  #
  def index
    prepare_user_var
    extra_javascript %w[clickable_row require_at_least_one_checkbox filter_form quick_action_menu]
    @button_bar_partial = 'new_advisory_button'


    if request.post?
      # Updating (or creating) a filter

      if params[:errata_filter][:id].present?
        # Updating an existing filter.
        @errata_filter = ErrataFilter.find(params[:errata_filter][:id])

        # The name field actually will be blank, but we want to keep the name, so do this.
        # The reason it is blank is because it is only visible when creating a new filter.
        params[:errata_filter].delete(:name)

        @errata_filter.update_attributes(params[:errata_filter])
        flash_message :notice, "Filter '#{@errata_filter.name}' updated"

      else
        # Creating a brand new filter
        @errata_filter = UserErrataFilter.create(params[:errata_filter])
        # TODO: check for validation failures here.

        flash_message :notice, "Filter '#{@errata_filter.name}' created"
      end

      # Redirect any time we are saving so that a reload won't create dupe filters.
      # Also it makes the visible url params much shorter and prettier.
      redirect_to :action=>:filter_permalink, :id => @errata_filter
      return

    else
      # Not updating, just displaying a filter

      if params[:search]
        # Special case so we can have nicer search urls.
        # This replaces /errata/find?advisory[name] and is used in the search box
        # in the top nav bar. See Bug 957586.
        search_text = params[:search].strip
        if search_text.match(/[0-9]+:[0-9]+/) || search_text.match(/^[0-9]+$/)
          # Search term looks like an advisory name or id. Try to find the advisory.
          @errata = begin
            Errata.find_by_advisory(search_text)
          rescue BadErrataID => e
            nil
          end

          if @errata
            # We found an advisory, redirect to it
            flash_message :alert, "Note: #{search_text} is an old id for this errata. It is now <b>#{@errata.fulladvisory}</b>" if @errata.old_advisory.try(:match, search_text)
            redirect_to :action => :view, :id => @errata
            return
          else
            # Didn't find a matching advisory
            redirect_to_error!("Unable to find errata with id: " + search_text)
            return
          end

        else
          # Search term looks like a text search so use make a filter to search on synopsis_text
          # Could do a redirect here but then the url would be long and ugly.
          @errata_filter = ErrataFilter.new(:filter_params => UserErrataFilter::FILTER_DEFAULTS_ALL.merge('synopsis_text' => search_text))

        end

      elsif !params[:errata_filter]
        # Must be first time on page so use default filter.
        @errata_filter = @user.default_filter || SystemErrataFilter.default

      elsif params[:errata_filter][:id].present?
        # Use an existing saved filter.
        if !ErrataFilter.exists?(params[:errata_filter][:id])
          flash_message :alert, "Couldn't find filter with id #{params[:errata_filter][:id]}"
          redirect_to({ :action=>:index })
          return
        else
          @errata_filter = ErrataFilter.find(params[:errata_filter][:id])
        end

      else
        # Use the params to make an adhoc unsaved filter.
        @errata_filter = UserErrataFilter.new(params[:errata_filter])

      end
    end

    # All the filtering and pagination happens in ErrataFilter#results.
    @erratas = @errata_filter.results(:page=>params[:page])

    # Because this does some suff with the @errata_filter.selected_releases
    # it has to be down here now so @errata_filter exists when it is called.
    prepare_drop_down_data
  end

  #
  # Fetch a list of advisories according to a predefined filter.
  #
  # :api-url: /filter/{id}.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # [
  #  {
  #    "id": 13392,
  #    "type": "RHBA",
  #    "text_only": false,
  #    "advisory_name": "RHBA-2012:13392",
  #    "synopsis": "udev bug fix and enhancement update",
  #    "revision": 1,
  #    "status": "NEW_FILES",
  #    "security_impact": "None",
  #    "respin_count": 0,
  #    "pushcount": 0,
  #    "timestamps": {
  #      "issue_date": "2012-06-29T09:34:43Z",
  #      "update_date": "2012-06-29T09:34:43Z",
  #      "release_date": null,
  #      "status_time": "2012-06-29T09:34:43Z",
  #      "created_at": "2012-06-29T09:34:43Z",
  #      "updated_at": "2012-06-29T09:34:43Z"
  #    },
  #    "flags": {
  #      "text_ready": false,
  #      "mailed": false,
  #      "pushed": false,
  #      "published": false,
  #      "deleted": false,
  #      "qa_complete": false,
  #      "rhn_complete": false,
  #      "doc_complete": false,
  #      "rhnqa": false,
  #      "closed": false,
  #      "sign_requested": false
  #    },
  #    "product": {
  #      "id": 16,
  #      "name": "Red Hat Enterprise Linux",
  #      "short_name": "RHEL"
  #    },
  #    "release": {
  #      "id": 224,
  #      "name": "RHEL-5.9.0"
  #    },
  #    "people": {
  #      "assigned_to": "qe-baseos-daemons@redhat.com",
  #      "reporter": "rbiba@redhat.com",
  #      "qe_group": "BaseOS QE - Daemons",
  #      "docs_group": "Core",
  #      "devel_group": "Default",
  #      "package_owner": "jskarvad@redhat.com"
  #    }
  #  },
  #  {
  #    "id": 13391,
  #    "type": "RHBA",
  #    "text_only": false,
  #    "advisory_name": "RHBA-2012:13391",
  #    "synopsis": "postfix bug fix and enhancement update",
  #    "revision": 1,
  #    "status": "QE",
  #    "security_impact": "None",
  #    "respin_count": 0,
  #    "pushcount": 0,
  #    "timestamps": {
  #      "issue_date": "2012-06-27T16:48:26Z",
  #      "update_date": "2012-06-27T16:48:26Z",
  #      "release_date": null,
  #      "status_time": "2012-06-29T08:12:05Z",
  #      "created_at": "2012-06-27T16:48:26Z",
  #      "updated_at": "2012-06-29T08:22:04Z"
  #    },
  #    "flags": {
  #      "text_ready": false,
  #      "mailed": false,
  #      "pushed": false,
  #      "published": false,
  #      "deleted": false,
  #      "qa_complete": false,
  #      "rhn_complete": false,
  #      "doc_complete": true,
  #      "rhnqa": false,
  #      "closed": false,
  #      "sign_requested": true
  #    },
  #    "product": {
  #      "id": 16,
  #      "name": "Red Hat Enterprise Linux",
  #      "short_name": "RHEL"
  #    },
  #    "release": {
  #      "id": 224,
  #      "name": "RHEL-5.9.0"
  #    },
  #    "people": {
  #      "assigned_to": "qe-baseos-daemons@redhat.com",
  #      "reporter": "jskarvad@redhat.com",
  #      "qe_group": "BaseOS QE - Daemons",
  #      "docs_group": "Mail Server",
  #      "devel_group": "Default",
  #      "package_owner": "jkysela@redhat.com"
  #    }
  #  }
  # ]
  # ````
  #
  # The filters used by this API must first be configured using the
  # Errata Tool UI.
  #
  # Note that the "Per page" option applied in the filter also affects
  # how many advisories are returned by this API.
  #
  def filter_permalink
    prepare_user_var
    @button_bar_partial = 'new_advisory_button'
    extra_javascript %w[require_at_least_one_checkbox filter_form]
    if params[:id].blank?
      flash_message :error, "Missing filter id"
      logger.error "#{Time.now}: Missing filter id, should not happen, see Bug 850607\n#{request.inspect}"
      redirect_to({ :action=>:index })
      return
    elsif !ErrataFilter.exists?(params[:id])
      flash_message :alert, "Couldn't find filter with id #{params[:id]}"
      redirect_to({ :action=>:index })
      return
    else
      @errata_filter = ErrataFilter.find(params[:id])
    end
    @erratas = @errata_filter.results(:page=>params[:page])
    prepare_drop_down_data
    render :action => "index"
  end

  def delete_filter
    if request.post? && (errata_filter = current_user.user_errata_filters.where(:id=>params[:errata_filter][:id]).first)
      errata_filter.delete
      flash_message :notice, "'Filter #{errata_filter.name}' deleted"
    else
      flash_message :error, "Could not delete filter"
    end
    redirect_to '/errata'
  end

  #
  # Fetch the details of a single advisory.
  #
  # :api-url: /advisory/{id}.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # {
  #   "id": 13391,
  #   "type": "RHBA",
  #   "text_only": false,
  #   "advisory_name": "RHBA-2012:13391",
  #   "synopsis": "postfix bug fix and enhancement update",
  #   "revision": 1,
  #   "status": "QE",
  #   "security_impact": "None",
  #   "respin_count": 0,
  #   "pushcount": 0,
  #   "timestamps": {
  #     "issue_date": "2012-06-27T16:48:26Z",
  #     "update_date": "2012-06-27T16:48:26Z",
  #     "release_date": null,
  #     "status_time": "2012-06-29T08:12:05Z",
  #     "created_at": "2012-06-27T16:48:26Z",
  #     "updated_at": "2012-06-29T08:22:04Z"
  #   },
  #   "flags": {
  #     "text_ready": false,
  #     "mailed": false,
  #     "pushed": false,
  #     "published": false,
  #     "deleted": false,
  #     "qa_complete": false,
  #     "rhn_complete": false,
  #     "doc_complete": true,
  #     "rhnqa": false,
  #     "closed": false,
  #     "sign_requested": true
  #   },
  #   "product": {
  #     "id": 16,
  #     "name": "Red Hat Enterprise Linux",
  #     "short_name": "RHEL"
  #   },
  #   "release": {
  #     "id": 224,
  #     "name": "RHEL-5.9.0"
  #   },
  #   "people": {
  #     "assigned_to": "qe-baseos-daemons@redhat.com",
  #     "reporter": "jskarvad@redhat.com",
  #     "qe_group": "BaseOS QE - Daemons",
  #     "docs_group": "Mail Server",
  #     "devel_group": "Default",
  #     "package_owner": "jskarvad@redhat.com"
  #   }
  # }
  # ````
  def view
    prepare_user_var
    prepare_advisory_tabs
    prepare_comment_opts

    @button_bar_partial = 'new_advisory_button'
    extra_javascript %w[errata_view charcount view_section cpe_list_helper]
    ajax_spinner
  end

  #
  # This one shows all advisory details and advisory content.
  # It is the 'Details' tab.
  #
  def details
    prepare_user_var
    prepare_advisory_tabs
    prepare_comment_opts

    @button_bar_partial = 'new_advisory_button'
    extra_javascript %w[errata_view view_section cpe_list_helper wrapped_unwrapped_text]
    extra_stylesheet %[wrapped_unwrapped_text]
    ajax_spinner
  end

  def cpe_list
    # unknown always appear first
    @cpes = Secalert::CpeMapper.new.cpe_list(@errata).sort_by{|k,v| [k =~ /unknown/ ? 0 : 1, k]}
    respond_to do |format|
      format.js {}
    end
  end

  #
  # Ask user how they would like to create an advisory
  #
  def new_choose
    case params[:create_choice]
    when 'manual'
      redirect_to :controller => :errata, :action => :new_errata
      return
    when 'quarterly'
      redirect_to :controller => :automatic_advisory, :action => :new_qu
      return
    when 'pdc_assisted'
      redirect_to :controller => :automatic_advisory, :action => :new_qu_pdc
      return
    when 'pdc_manual'
      redirect_to :controller => :errata, :action => :new_pdc_errata
      return
    end
    # Otherwise just show the form
  end

  # Note: There is a old change_status method in ErrataController
  # That method has some extra stuff in it like changing the QE
  # owner and the QE group. Also it has some RJS to do some
  # form show/hide on the browser.
  #
  # This version is going to do only one thing, ie change the state.
  #
  def change_state
    back_to = params[:back_to].present? ? params[:back_to] : 'view'
    prepare_user_var
    prepare_state_transitions

    if request.post?
      new_state = params[:new_state]
      comment_text = params[:comment]
      if new_state.blank?
        flash_message :error, "Please select state to change to"
      else
        begin
          @errata.change_state!(new_state, @user, comment_text)
          flash_message :notice, render_to_string(:inline => "State changed to <%= state_display('#{new_state}').html_safe %>.")
        rescue => ex
          flash_message :error, render_to_string(:inline => ex.message)
        end
      end
      redirect_to :action => back_to, :id => @errata
    end
  end

  #
  # This duplicates some stuff in the old change_status.
  # Not going to use ajax though to keep things simple.
  #
  def change_owner
    prepare_user_var
    if request.post?
      back_to = params[:back_to].present? ? params[:back_to] : 'view'
      comment_text = params[:comment]
      extra_comment = []

      current_qe_user  = @errata.assigned_to
      new_qe_user  = User.find(params[:new_qe_user_id])
      old_qe_user  = User.find(params[:old_qe_user_id])

      current_qe_group = @errata.quality_responsibility
      new_qe_group = QualityResponsibility.find(params[:new_qe_group_id])
      old_qe_group = QualityResponsibility.find(params[:old_qe_group_id])

      need_to_save = false

      if new_qe_user != old_qe_user
        if old_qe_user != current_qe_user
          # Someone else changed it while we weren't looking
          flash_message :alert, "The advisory has been changed already to #{current_qe_user}"
          redirect_to :action => back_to, :id => @errata
          return
        else
          # Okay let's do it (not saving yet...)
          extra_comment << "Changed QE owner from #{current_qe_user} to #{new_qe_user}"
          @errata.assigned_to = new_qe_user
          need_to_save = true
        end
      end

      if new_qe_group != old_qe_group
        if old_qe_group != current_qe_group
          # Someone else changed it while we weren't looking
          flash_message :alert, "The advisory has been changed already to #{current_qe_group.name}"
          redirect_to :action => back_to, :id => @errata
          return
        else
          # Okay let's do it (not saving yet...)
          extra_comment << "Changed QE group from #{old_qe_group.name} to #{new_qe_group.name}"
          @errata.quality_responsibility = new_qe_group
          need_to_save = true
        end
      end

      if need_to_save
        @errata.save!
        @errata.comments.create(:who => @user, :text => "#{"\"#{comment_text}\"\n" if comment_text.present?}#{extra_comment.join("\n")}")
        flash_message :notice, extra_comment.join("\n")
      else
        flash_message :alert, "Nothing changed"
      end

      redirect_to :action => back_to, :id => @errata
    end
  end

  #
  # Content here means push content, i.e. what content does this advisory push out to customers
  #
  def content
    extra_javascript 'errata_content'
    extra_stylesheet 'errata_content'
    prepare_advisory_tabs

    # What mappings might be applicable
    @relevant_mappings = MultiProductMap.possibly_relevant_mappings_for_advisory(@errata)

    # Do this so we don't have to initialize or unique the lists
    @brew_build_dist_map = Hash.new { |h, k| h[k] = {
      :dists => Set.new, :mapped_dists => Set.new, :dist_files => HashSet.new, :mapped_dist_files => HashSet.new } }

    # Prepare block to run for channel and cdn repo iterators
    collect_dists = lambda do |brew_build, file, variant, arch, dists, mapped_dists|
      # (Turn any nils into empty arrays)
      dists = Array.wrap(dists)
      mapped_dists = Array.wrap(mapped_dists)

      # Collect a list of dists per build
      @brew_build_dist_map[brew_build][:dists] += dists
      @brew_build_dist_map[brew_build][:mapped_dists] += mapped_dists

      # Also collect a list of files in each build-dist
      dists.each { |dist| @brew_build_dist_map[brew_build][:dist_files][dist] << file }
      mapped_dists.each { |dist| @brew_build_dist_map[brew_build][:mapped_dist_files][dist] << file }
    end

    # Now populate @brew_build_dist_map
    # Show multi product supported contents even if it was disabled to give users an idea
    options = {:supports_multi_product_destinations => true}
    Push::Rhn.file_channel_map(@errata, options, &collect_dists)
    Push::Cdn.file_repo_map(@errata, options, &collect_dists)
  end

  def container
    if !@errata.has_docker?
      flash_message :error, "This advisory does not contain any docker images."
      redirect_to :action => :view, :id => @errata
    end
    @force_update = params[:force_update]
    extra_javascript %w[container_content errata_view]
    prepare_advisory_tabs
    ajax_spinner
  end

  def container_content
    cache_mode = params[:force_update] ? :force_update : :update_changed
    set_container_content(cache_mode)
    render :partial => 'errata/container/container_content'
  end

  def modal_container_text
    set_container_content
    render :partial => 'errata/container/container_text_modal'
  end

  private

  def set_container_content(cache_mode = :lazy_fetch)
    warnings = []
    mxor = Metaxor.new(:warn_on_error => true)
    @container_content = mxor.container_content_for_builds(@errata.brew_builds, cache_mode)
    if mxor.warnings.any?
      # set response header so alert flash can be shown by javascript
      response.headers['X-ET-Alert'] = mxor.warnings.join("<br>")
    end
  end

  def can_drop_advisory?
    t = StateTransition.find_by_from_and_to @errata.status, State::DROPPED_NO_SHIP
    if t.try(:performable_by?, current_user)
      return true if current_user.in_role?('secalert') || @errata.bugs.security_restricted.empty?
    end
    if @errata.bugs.security_restricted.any?
      flash_message :error, 'You do not have permission to drop this advisory, since it contains security restricted bugs. Please contact secalert@redhat.com to drop this advisory.'
    else
      flash_message :error, "You do not have permission to drop an advisory from #{@errata.status} state. Please contact product management to drop this advisory."
    end
    redirect_to :action => :view, :id => @errata
    false
  end

  def can_edit_advisory?
    return true if @advisory.allow_edit?
    # Can't edit an advisory that is shipped live
    flash_message :error, "
        Can't edit advisory '#{@advisory.fulladvisory}' in status #{@advisory.status}.<br/>
        (Please move the advisory back to status REL_PREP if you need to change it).
      "
    redirect_to :action => :view, :id => @advisory
    false
  end
  # Some these could be before_filters maybe...
  def prepare_drop_down_data
    @user_filters       = UserErrataFilter.for_user(@user).order('name ASC')
    @system_filters     = SystemErrataFilter.in_display_order

    # Note that we don't show checkboxes for the Pdc types
    @errata_types       = ErrataType.legacy.map { |t| [ t.name, t.short_desc ] }

    @errata_states      = State.all_states.map { |s| [ s.to_s, State.nice_label(s, :short => true) ] }

    @products           = Product.active_products
    @batches            = Batch.active
    @all_batches        = Batch.all

    @content_types      = ['None', 'rpm', 'docker', BrewArchiveType.pluck(:name)].flatten

    # If the release in the filter isn't current then it won't be visible in the drop down, causing
    # confusion. Here's a hack to get around this.
    @filter_releases    = Release.where('id in (?)',@errata_filter.selected_releases).includes(:product)
    @current_releases   = Release.current.includes(:product)
    @current_and_filter_releases = (@current_releases + @filter_releases).uniq

    @all_releases       = Release.includes(:product)

    @sort_options       = ErrataFilter.sort_options_for_select
    @format_options     = ErrataFilter.format_options_for_select
    @pagination_options = @errata_filter.pagination_options_for_select
    @group_by_options   = ErrataFilter.group_by_options_for_select
    @doc_status_options = ErrataFilter.docs_status_options_for_select
    @security_approval_options = ErrataFilter.security_approval_options_for_select
    @open_closed_options = ErrataFilter.open_closed_options_for_select
    @text_only_options  = ErrataFilter.text_only_options_for_select

    prepare_qe_dropdowns

    @devel_groups = UserOrganization.devel_groups

    @reporters = User.all_reporters

    #
    # Eek. confusing..! it is for the grouped select..
    # Should look something like this:
    # [
    #   'RHEL', [
    #     ['RHEL-6.3.z', 123],
    #     ['RHEL-6.2', 232],
    #   ],
    #   'Cloudforms, [
    #     ['Cloudforms 1.2.3', 343],
    #     ['Cloudforms 1.2.4', 654],
    #   ],
    #   etc..
    # ]
    #
    @all_releases_grouped = @all_releases.
      group_by { |r|   r.try(:product).try(:short_name)||'(No Product)' }.
      map      { |k,v| [k, v.sort_by{ |r| r.name }.map{ |r| [r.name_with_inactive, r.id] }] }.
      sort_by  { |r|   r[0] }

    @current_releases_grouped = (@current_and_filter_releases).uniq.
      group_by { |r|   r.try(:product).try(:short_name)||'(No Product)' }.
      map      { |k,v| [k, v.sort_by{ |r| r.name }.map{ |r| [r.name_with_inactive, r.id] }] }.
      sort_by  { |r|   r[0] }

  end

  def prepare_user_var
    @user = User.current_user
  end

  def prepare_advisory_tabs
    @secondary_nav = get_secondary_nav
    set_index_nav
  end

  def prepare_state_transitions
    @transitions = states_for_ui_select @errata, State.get_transitions(@user, @errata)
    # By 'normal' I mean it is a transition that could happen
    # given no blockers and no special admin powers...
    @normal_transitions = states_for_ui_select @errata, StateTransition.user_selectable.from_state(@errata.status).map(&:to)
  end

  def prepare_qe_dropdowns
    @qe_groups =  QualityResponsibility.order('name')
    @qe_owners =  Role.qa_people.order('login_name')
  end

  def prepare_comment_opts
    # This one is a bit weird because we allow the user preference to be
    # overridden with a url param.
    @comments_newest_first = if params[:cs]
      params[:cs] == 'newest'
    else
      user_pref(:comments_newest_first)
    end
  end

  def states_for_ui_select(errata, states)
    states << errata.status
    states.uniq
  end

  #------------------------------------------------------------
  #------------------------------------------------------------

  private # still...

  def advisory_to_hash(e)
    { :id => e.id,
      :advisory_name => e.advisory_name,
      :product => e.product.name,
      :release => e.release.name,
      :synopsis => e.synopsis,
      :release_date => e.release_date ? e.release_date.to_date.to_s(:long) : nil,
      :qe_owner => e.assigned_to.login_name,
      :qe_group => e.quality_responsibility.name,
      :status => e.status.to_s,
      :status_time => e.status_updated_at.to_s(:long)
    }
  end

  def advisory_list_to_json(advisories)
    advisories.collect { |e| advisory_to_hash(e) }.to_json
  end

  def set_advisory_form
    @advisory = UpdateAdvisoryForm.new(User.current_user, params) if params[:id]
    @advisory ||= CreateAdvisoryForm.new(User.current_user, params)
  end

  def check_spelling(text)
    errors = []
    dictionary = Rails.root.join("app/controllers/dictionary")
    optionally do
      IO.popen("hunspell -l -p #{dictionary}", "w+") do |spell|
        spell.puts text
        spell.close_write
        spell.each { |s| errors << s.chop }
      end
    end
    return errors.uniq
  end

  def render_channel_files
    respond_to do |format|
      format.xml  { render :layout => false }
      format.text do
        text = []
        @channel_files.each_pair do |c, files|
          text << files.to_a.unshift(c).join(',')
        end
        render :text => text.join("\n") + "\n"
      end
      format.json do
        render :layout => false,
        :json => @channel_files.to_json
      end
    end
  end

  def reconcile_bugs_for_rhsa
    return true unless @errata.is_security?
    return true if Rails.env.development?

    optionally do
      bz = Bugzilla::Rpc.get_connection
      bz.reconcile_bugs(@errata.bugs.collect { |b| b.id })
      @errata = Errata.find(@errata.id)
    end
    return true
  end

  def set_releases_for(product)
    @user = current_user unless @user
    # pusherrata role members no longer see disabled releases. Bug 669168.
    # dmach says: "If a product is disabled and a new advisory is needed for
    # some reason, we'll just enable it, file an advisory and disable it again.
    # Do not show releases with approved components #bz 739011
    @releases = Release.current.enabled.for_products(product)
    unless @user.in_role?('secalert')
        @releases = @releases.no_approved_components
    end
    @releases = @releases.order(:name)
    if @advisory && !@advisory.new_record?
      @releases.unshift @advisory.release
    end

    # createasync role members always see ASYNC release at the top
    @releases.unshift Release.find_by_name('ASYNC') if @user.can_create_async?
    @releases.uniq!

    @releases = advisory_is_pdc? ? @releases.select(&:is_pdc) : @releases.reject(&:is_pdc)
    return @releases
  end

  def set_defaults_for_create
    @product = Product.find_by_short_name('RHEL') || Product.first
    set_releases_for @product

    @release = @product.releases.first
    @products = Product.active_products
  end

  def set_default_for_pdc_create
    @products = Product.active_products.supports_pdc
    @product = @products.first
    set_releases_for(@product) if @product
    @release = @product.releases.first if @product
  end

  def advisory_is_pdc?
    return @advisory.is_pdc? if @advisory
    # in creating page or change product in create/edit page
    creating_pdc_advisory? || params['is_pdc'] == 'true'
  end

  def creating_pdc_advisory?
    params[:action] == 'new_pdc_errata'
  end

  #
  # Show a warning message if the advisory is not automatically
  # assigned. This is to avoid the risk an RHSA advisory being
  # overlooked by the user.
  # Bug: 1036148
  #
  def remind_user_of_unassigned_advisory
    advisory = @advisory.try(:errata)
    advisory ||= @errata
    if advisory.assigned_to_default_qa_user?
      flash_message :alert, "Advisory is currently unassigned. Please <a href='#' class='open-modal' data-modal-id='change_owner_modal'>assign a QE owner</a>."
    end
  end

  protected

  #
  # This is used by preview and by save_errata above.
  # Reads from params and creates @manager and @package_owner
  # Contact.new(nil) is valid (?) and will return an object.
  #
  def get_manager_and_package_owner
    manager_login = nil
    manager_login = params[:manager][:login_name] if params[:manager]
    @manager = Contact.new(manager_login)

    package_owner_login = nil
    package_owner_login = params[:package_owner][:login_name] if params[:package_owner]
    @package_owner = Contact.new(package_owner_login)
  end

  # Used to let user know if rule set will be changed
  def ruleset_will_change?(errata, release, product)
    new_default_ruleset = release.state_machine_rule_set || product.state_machine_rule_set
    # (If it has a custom rule set then it will not change regardless of the release & product)
    errata.custom_state_machine_rule_set.nil? && errata.state_machine_rule_set != new_default_ruleset
  end

  def change_security_approved_to(new_value)
    old_value = @advisory.security_approved
    @advisory.params[:advisory] = {:security_approved => new_value}
    @advisory.update_attributes
    @advisory.save!

    what = SecurityWorkflow::SECURITY_APPROVED_TRANSITIONS[[old_value,new_value]][:what]
    flash_message :notice, "Product Security approval has been #{what}."
    redirect_to :back
  end
end
