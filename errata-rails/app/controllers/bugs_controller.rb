require 'set'
require 'shared_controller_nav'

# :api-category: Legacy
class BugsController < ApplicationController
  include SharedControllerNav, ReplaceHtml

  before_filter :find_errata, :only => [:add_bugs_to_errata, :remove_bugs_from_errata, :change_bugs, :for_errata, :updatebugstates]

  before_filter :set_index_nav, :only => [:index, :for_release, :qublockers, :approved_components,
    :added_since, :add_bugs_to_errata, :remove_bugs_from_errata, :troubleshoot]

  before_filter :time_since, :only => [:added_since]

  before_filter :advisory_in_new_files, :only => [:add_bugs_to_errata, :remove_bugs_from_errata]

  before_filter :reset_packages_with_advisories

  before_filter :set_log_limit, :only => [:troubleshoot]

  respond_to :html, :json

  def index
    redirect_to :controller => :issues, :action => :index
  end

  #
  # Fetch a bug.
  #
  # :api-url: /bugs/{id}.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # {
  #   "bug": {
  #     "id": 251677,
  #     "is_security": false,
  #     "last_updated": "2012-06-27T16:49:15Z",
  #     "qa_whiteboard": "gradeA",
  #     "reconciled_at": "2012-06-27T16:54:14Z",
  #     "alias": "",
  #     "release_notes": "",
  #     "flags": "qe_test_coverage-, rhel-5.7.0-, rhel-5.8.0-, rhel-5.9.0+, pm_ack+, devel_ack+, qa_ack+",
  #     "is_exception": false,
  #     "is_private": false,
  #     "package": "postfix",
  #     "pm_score": 500,
  #     "short_desc": "example scripts missing",
  #     "was_marked_on_qa": true,
  #     "bug_status": "ON_QA",
  #     "issuetrackers": "",
  #     "keywords": "",
  #     "priority": "low",
  #     "verified": "",
  #     "bug_severity": "low",
  #     "is_blocker": false
  #   }
  # }
  # ````
  def show
    @bug = Bug.find(params[:id])
    respond_with(@bug)
  end

  def add_bugs_to_errata
    unless @errata.release.blocker_flags?
      redirect_to :action => 'edit', :controller => 'errata', :id => @errata
      return
    end

    if request.post?
      chosen = get_selected_bugs
      logger.debug "BUGS There are #{chosen.length} new bugs: #{chosen.join(',')}"
      if chosen.empty?
        flash_message :alert, 'No bugs have been added'
      else
        logger.debug "BUGS Adding #{chosen.length} bugs to #{@errata.id}"
        new_bugs = Bug.find(chosen)
        logger.debug "BUGS Got back #{new_bugs.length} bugs from query"
        fbs = FiledBugSet.new(:bugs => new_bugs, :errata => @errata)
        if fbs.save
          send_messages(new_bugs, @errata)
          flash_message :notice, "Added: #{new_bugs.map(&:id).join(', ')}"
        else
          flash_message :error, "Error adding bugs: #{fbs.errors.full_messages.join(',')}"
        end
      end
      redirect_to :action => :view, :controller => :errata, :id => @errata
    else
      set_page_title "Add Bugs to #{@errata.shortadvisory}"
      release_bugs = get_bugs_for_release(@errata.release)
      package_bugs = []
      unless @errata.text_only?
        @errata.brew_builds.each do |build|
          bugs = get_bugs_for_release(@errata.release, build)
          package_bugs.concat(bugs)
        end
      end
      current_bugs = @errata.bugs.collect { |b| b.id }.uniq
      @release_bugs = release_bugs.uniq - package_bugs - current_bugs
      @package_bugs = package_bugs.uniq - current_bugs
    end
  end

  # TODO: Support PDC
  def approved_components
    if params[:id]
      @release = Release.url_find(params[:id])
    else
      @release = BugsController.releases_with_approved_components.first
    end

    mapcond = "current = 1 and errata_brew_mappings.errata_id in " +
      "(select id from errata_main where is_valid = 1 and status not in ('UNFILED', 'DROPPED_NO_SHIP') and  group_id = ?)"

    maps = ErrataBrewMapping.for_rpms.where(mapcond, @release).includes([:errata, :package])
    @pkg_errata = { }
    maps.each do |map|
      @pkg_errata[map.package] = map.errata
    end
    set_page_title "Approved Components for #{@release.name}"
    respond_to do |format|
      format.html
      format.json { render :json => @pkg_errata.to_json, :layout => false}
      format.xml  { render :layout => false }
    end
  end

  def added_since
    @filed_bugs = FiledBug.find(:all,
                                :conditions => ['filed_bugs.created_at >= ?', @since],
                                :include => [:errata, :bug, :user],
                                :order => 'filed_bugs.created_at')
    title = "Bugs Added "
    title += "Since " unless @timeframe == 'today'
    set_page_title title + @timeframe.capitalize
  end

  #
  # Fetch the list of advisories which refer to a particular bug.
  #
  # :api-url: /bugs/{id}/advisories.json
  # :api-method: GET
  #
  # Returns an array of advisories.  Each advisory is in the same format as
  # used by [/advisory/{id}.json].
  def errata_for_bug
    @bug = Bug.find(params[:id])
    @filed_bugs = FiledBug.includes(:errata).where(:bug_id => @bug)
    respond_with(@filed_bugs)
  end

  #
  # Fetch the bugs associated with an advisory.
  #
  # :api-url: /advisory/{id}/bugs.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # [
  #  {
  #    "id": 251677,
  #    "is_security": false,
  #    "last_updated": "2012-06-27T16:49:15Z",
  #    "qa_whiteboard": "gradeA",
  #    "reconciled_at": "2012-06-27T16:54:14Z",
  #    "alias": "",
  #    "release_notes": "",
  #    "flags": "qe_test_coverage-, rhel-5.7.0-, rhel-5.8.0-, rhel-5.9.0+, pm_ack+, devel_ack+, qa_ack+",
  #    "is_exception": false,
  #    "is_private": false,
  #    "package": "postfix",
  #    "pm_score": 500,
  #    "short_desc": "example scripts missing",
  #    "was_marked_on_qa": true,
  #    "bug_status": "ON_QA",
  #    "issuetrackers": "",
  #    "keywords": "",
  #    "priority": "low",
  #    "verified": "",
  #    "bug_severity": "low",
  #    "is_blocker": false
  #  },
  #  {
  #    "id": 456718,
  #    "is_security": false,
  #    "last_updated": "2012-06-27T16:49:18Z",
  #    "qa_whiteboard": "RHTSdone",
  #    "reconciled_at": "2012-06-27T16:54:14Z",
  #    "alias": "",
  #    "release_notes": "",
  #    "flags": "rhel-5.9.0+, blocker+",
  #    "is_exception": false,
  #    "is_private": true,
  #    "package": "postfix",
  #    "pm_score": 1500,
  #    "short_desc": "CVE-2008-2936 postfix privilege escalation flaw [rhel-5.9]",
  #    "was_marked_on_qa": true,
  #    "bug_status": "ON_QA",
  #    "issuetrackers": "",
  #    "keywords": "Security, SecurityTracking, ZStream",
  #    "priority": "medium",
  #    "verified": "",
  #    "bug_severity": "medium",
  #    "is_blocker": true
  #  }
  # ]
  # ````
  def for_errata
    set_page_title "Bugs for #{@errata.advisory_name}<br/><span class='light tiny'>#{@errata.synopsis}</span>".html_safe, :no_auto_title=>true
    respond_with(@errata)
  end

  def for_release
    extra_javascript 'bugs_for_release'
    release_id = params[:id] if params[:id]
    if params[:release] && params[:release][:id]
      release_id = params[:release][:id]
    end
    release_id = params[:release_id] unless release_id
        
    @release = Release.url_find(release_id) if release_id

    redirect = request.post?
    unless @release
      @release = Release.find(:first, 
                             :conditions => ['enabled = 1 and isactive = 1 and product_id = ?', 
                                             Product.find_by_short_name('RHEL')])
      redirect = true
    end
    
    if redirect
      redirect_to :action => 'for_release', :controller => 'bugs', :id => @release.url_name
      return
    end
    
    set_page_title "Bugs by Advisory for #{@release.name}"
    
    respond_to do |format|
      format.html
      format.json { render :layout => false, :json => @release.bugs.to_json }
      format.xml  { render :layout => false }
    end

  end
  
  def change_bugs
    redirect_to :action => :add_bugs_to_errata, :id => @errata
  end
  
  def reconcile_bugs
    if request.post?
      errata = Errata.find(params[:id])
      bz = Bugzilla::Rpc.get_connection
      diffs = bz.reconcile_bugs(errata.bugs.collect { |b| b.id })
    end
    redirect_to :action => :view, :controller => :errata, :id => errata
  end

  def remove_bugs_from_errata
    unless request.post?
      set_page_title "Remove Bugs From #{@errata.shortadvisory}"
      @can_be_dropped, @undroppable = @errata.bugs.collect {|b| DroppedBug.new(:errata => @errata, :bug => b)}.partition {|db| db.valid? }
      @can_be_dropped = @can_be_dropped.map(&:bug)
      return
    end

    chosen = get_selected_bugs
    if chosen.empty?
      flash_message :alert, 'No bugs have been removed'
    else
      dead_bugs = Bug.find(chosen)
      dbs = DroppedBugSet.new(:bugs => dead_bugs, :errata => @errata)
      if dbs.save
        send_messages(dead_bugs, @errata, true)
        flash_message :notice, "Removed: #{dead_bugs.map(&:id).join(', ')}"
      else
        flash_message :error, "Error dropping bugs: #{dbs.errors.full_messages.join(',')}"
      end
    end
    redirect_to :action => :view, :controller => 'errata', :id => @errata
  end

  def find_errata_for_bug
    unless request.post?
      redirect_to :action => 'index'
      return
    end
    
    id = params[:bug][:id]
    id.strip!
    
    if id.empty?
      flash_message :error, "Empty bug id!"
      redirect_to :action => 'index'
      return
    end
    unless id =~ /^[0-9]+$/
      bug = Bug.find_by_alias(id)
      unless bug
        flash_message :error, "No such bug alias #{id}"
        redirect_to :action => 'index'
        return
      end
      id = bug.id
    end
    redirect_to :action => :errata_for_bug, :id => id
  end

  def qublockers
    @releases = QuarterlyUpdate.find(:all, :conditions => 'enabled = 1 and isactive = 1')
    set_current_release
    set_page_title "Bug Coverage for Release #{@current_release.name}"
    list = @current_release.bugs.active.select(:id)
    @covered = FiledBug.includes({:bug => :package}, :errata).where(:bug_id => list)

    uncovered = @current_release.bugs.includes(:package).active.unfiled
    @uncovered_by_component = Hash.new { |hash, key| hash[key] = []}
    uncovered.each do |bug|
      @uncovered_by_component[bug.package] << bug
    end
    @total_bugs = list.length
  end

  def erratabugs
    redirect_to :action => :for_release, :id => params[:id], :release_id => params[:release_id] 
  end


  def updatebugstates
    set_page_title "Update Bugs States For #{@errata.shortadvisory}"
    # (The form will be rendered if not posting)
    return unless request.post?

    _update_bug_states
    return unless request.format.html?
    redirect_to :action => :view, :controller => 'errata', :id => @errata
  end

  def releases_for_product
    product = Product.find(params[:product][:id])
    releases = product.active_releases
    release = releases.first
    js = js_for_template(:release_list,
                         'release_list',
                         {:object => releases, :locals => {:release => release}})
    js += js_for_template :errata_bug_list, 'errata_bug_list', :object => release
    render_js js
  end

  #
  # For a single bug try to answer questions such as
  # * Is it synced with Bugzilla?
  # * Why can't I add this to an advisory
  # * Why can't I create a Y-stream advisory with this bug
  #
  def troubleshoot
    extra_javascript %w[troubleshoot view_section]
    @bug_id = params[:bug_id]
    if (@bug = Bug.find_by_id(@bug_id))

      # It's possible there are many releases the bug might be added to.
      # Going to pick one initially, but give the user a chance to change it
      # by clicking on a link that sets a release_id param
      @specified_release = Release.find(params[:release_id]) if params[:release_id]
      # If the release isn't a possible release for this bug then ignore it
      @specified_release = nil unless @bug.possible_releases.include?(@specified_release)
      # Pick the release to display
      @release = @specified_release || @bug.guess_release_from_flag
      # Use this to display the other options to the user
      @other_releases = @bug.possible_releases - [@release]

      @package = @bug.package
      @not_filed_already_check = @bug.errata.empty?

      # Probably needs some extra work here...
      if @release
        # TODO: Use some named scope for this
        @approved_components = ReleaseComponent.where(:release_id => @release.id).
          map{ |rc| rc.package }.
          sort_by{ |pkg| pkg.name.downcase }
      end

      # This will do the tests and show the results and explanations
      @check_list = BugEligibility::CheckList.new(@bug, :release=>@release, :enable_links=>true)

      set_page_title "Advisory Eligibility - Bug #{@bug_id} <span class='tiny superlight'>#{@bug.short_desc}</span>".html_safe

    elsif @bug_id.present?
      set_page_title "Bug #{@bug_id} unknown to Errata Tool"

    else
      set_page_title "Bug Advisory Eligibility"

    end
  end

  #
  # This reconciles a single bug and redirects back to the
  # troubleshoot action.
  #
  # See also reconcile_bugs.
  #
  def troubleshoot_sync_bug
    return unless request.post? # fixme, use proper filter...

    bug_id = params[:bug_id].strip.to_i

    begin
      if Bug.exists?(bug_id)
        Bugzilla::Rpc.get_connection.reconcile_bugs([bug_id])
        flash_message :notice, "Bug #{bug_id} synced with Bugzilla"
      else
        Bug.make_from_rpc(Bugzilla::Rpc.get_connection.get_bugs([bug_id]).first)
        flash_message :notice, "Bug #{bug_id} found in Bugzilla and created"
      end
    rescue XMLRPC::FaultException => e
      flash_message :error, "Problem syncing bug #{bug_id}: #{e.message}"
    end

    redirect_to :action=>:troubleshoot, :bug_id=>bug_id
  end

  #
  # This does a sync of the approved component list with bugzilla
  # and redirects back to the troubleshoot action.
  #
  def troubleshoot_update_approved_components
    return unless request.post? # fixme, use proper filter...

    bug_id = params[:bug_id]
    release_id = params[:release_id]
    release = Release.find_by_id(release_id)

    if release
      release.update_approved_components!
      flash_message :notice, "Approved components for #{release.name} synced"
    else
      flash_message :error, "Error: Couldn't find release id #{release_id}"
    end
    redirect_to :action=>:troubleshoot, :bug_id=>bug_id, :release_id=>release_id
  end

  private

  def advisory_in_new_files
    return true if @errata.status == State::NEW_FILES

    flash_message :notice, 'Advisory must be in NEW_FILES state to change bug list'
    redirect_to :action => :view, :controller => :errata, :id => @errata
    false
  end

  #
  # Returns the names of rpms built by this brew build
  #
  def built_rpm_names(build)
    build.
      # Just names from the rpms without nvr info
      brew_rpms.map(&:name_nonvr).
      # Remove any duplicates
      uniq.
      # Filter out any debuginfo names
      reject{ |name| name =~ /debuginfo/ }.
      # Remove prefixes if there are any for this product. (Mainly for SCL, see Bug 1003719)
      map { |name| BrewRpmNamePrefix.strip_using_list_of_prefixes(@errata.product.brew_rpm_name_prefixes, name) }
  end

  def valid_bug_state?(b)
    valid_states = if b.has_keyword?('TestOnly')
      %w{ON_QA VERIFIED}
    else
      @errata.product.valid_bug_states
    end
    return valid_states.include?(b.bug_status)
  end

  def get_bugs_for_release(release, build = nil)
    bugs = []
    return bugs if release.blocker_flags.empty?

    if build.nil?
      bugs = release.get_bugs.unfiled
      if release.supports_component_acl?
        bugs = bugs.where(:package_id => release.approved_component_ids)
      end
      if release.is_ystream? && !release.allow_pkg_dupes?
        bugs = bugs.reject { |b| existing_advisory_for_component(b.package_id)}
      end
      bugs = bugs.select { |b| valid_bug_state?(b)}
    else
      rpms = built_rpm_names(build)
      if release.is_ystream? && !release.allow_pkg_dupes?
        rpms = rpms.reject{|pkg| existing_advisory_for_component(pkg)}
      end
      rpms.each do |pkg|
        list = release.get_bugs(pkg).unfiled
        bugs.concat(list.select { |b| valid_bug_state?(b)})
      end
    end
    return bugs
  end

  def existing_advisory_for_component(pkg)
    packages_with_advisories.include?(pkg)
  end

  # returns list with IDs _and_ names for all packages included in an advisory for this release
  # (except for the current advisory)
  def packages_with_advisories
    @packages_with_advisories ||= ReleaseComponent.includes(:package)\
      .where('errata_id != ? AND errata_id IN (?)', @errata, @errata.release.errata)\
      .map{|m| [m.package.name, m.package.id]}\
      .flatten.uniq
  end

  def reset_packages_with_advisories
    @packages_with_advisories = nil
  end

  def get_secondary_nav
    if ['add_bugs_to_errata', 'remove_bugs_from_errata'].include?(params[:action])
      return get_errata_secondary_nav
    end
    BugsController.get_secondary_nav
  end

  def self.get_secondary_nav
    nav = []

    nav << { :name => 'Bug Search',
      :controller => :issues,
      :action => :index,
      :title => 'Search for which errata cover a given bug/issue'}

    nav << { :name => 'Bug Advisory Eligibility',
      :controller => :bugs,
      :action => :troubleshoot,
      :title => 'Troubleshoot why a bug is not able to be added to an advisory'}

    nav << { :name => 'Sync Bug List',
      :controller => :issues,
      :action => :sync_issue_list,
      :title => 'Sync/reconcile a given list of bug ids/issue keys'}

    nav << { :name => 'Blocker Bug Coverage', 
      :controller => :bugs, 
      :action => :qublockers,
      :title => 'Shows which errata fix Quarterly Update blocker bugs, and which blocker bugs are not fixed yet in any errata'}

    nav << { :name => 'Bugs for Release', 
      :controller => :bugs,
      :action => :for_release,
      :title => 'Shows all the bugzillas in for each errata in a Quarterly Update, and indicates which errata have bugs not on the QU blocker list.'}
    
    nav << { :name => 'Added Since',
      :controller => :bugs,
      :action => :added_since,
      :title => 'Shows all the bugs added to errata since yesterday, last month, etc.'}
    
    BugsController.releases_with_approved_components.each do |r|
      nav << { :name => "#{r.name}",
        :controller => :bugs,
        :action => :approved_components,
        :id => r.url_name,
        :title => "Approved Components for #{r.name}"}
    end
    
    return nav
  end

  def get_errata_secondary_nav
    [
      { :name => 'Add Bugs',
        :controller => :bugs,
        :action => :add_bugs_to_errata,
        :title => 'Add bugs to advisory',
        :id => @errata.id},
      { :name => 'Remove Bugs',
        :controller => :bugs,
        :action => :remove_bugs_from_errata,
        :title => 'Remove bugs from advisory',
        :id => @errata.id}
    ]
  end
  
  def get_selected_bugs
    @selected = params[:bug]
    chosen = IssuesController.get_selected_issues(@selected)
  end

  def self.releases_with_approved_components
    QuarterlyUpdate.find(:all,
                         :conditions => 
                         ['enabled = 1 and isactive = 1 and id in (select release_id from release_components)']
                         )
  end
  
  def set_current_release
    release_id = params[:release_id]

    unless release_id
      @current_release = @releases.first
      return
    end

    if release_id =~ /^[0-9]+$/
      @current_release = Release.find(release_id.to_i)
    else
      @current_release = Release.find_by_url_name(release_id)      
    end
  end

  def set_log_limit
    @log_limit = params[:log_limit].to_i
    @log_limit = 50 if @log_limit <= 0
  end

  def send_messages(bugs, errata, is_dropped = false)
    msg_header = {
      'subject' => 'errata.bugs.changed',
      'who' => User.current_user.login_name,
      'when' => Time.zone.now.to_s(:db_time_now),
      'errata_id' => errata.id
    }

    issues = bugs.each_with_object([]) { |bug, issues| issues << {id: bug.id, type: 'RHBZ'} }

    msg_body = {
      'who' => User.current_user.login_name,
      'when' => Time.zone.now.to_s(:db_time_now),
      'errata_id' => errata.id,
      'added' => is_dropped ? [].to_json : issues.to_json,
      'dropped' => is_dropped ? issues.to_json : [].to_json
    }

    MessageBus.enqueue(
      'errata.bugs.changed', msg_body, msg_header,
      :embargoed => errata.is_embargoed?
    )
  end

  def _update_bug_states
    newstates = params[:bug]

    changed_bugs = @errata.bugs.select do |b|
      newstates[b.bug_id.to_s].present? && b.bug_status != newstates[b.bug_id.to_s]
    end
    logger.debug "#{changed_bugs.length} bugs changed"
    return if changed_bugs.empty?

    rpc = Bugzilla::Rpc.get_connection
    rpcbugs = rpc.get_bugs(changed_bugs.collect { |b| b.bug_id})
    rpc_states = Hash[ *rpcbugs.collect {|b| [b.bug_id, b]}.flatten ]

    ok_bugs, collision_bugs = changed_bugs.partition { |b| b.bug_status == rpc_states[b.bug_id].bug_status }
    unless collision_bugs.empty?
      logger.debug "Collisions"
      warnings = ['Could not update these bugs due to state collisions:']
      collision_bugs.each do |b|
        warnings << "Bug #{b.bug_id} already changed from #{b.bug_status} to #{rpc_states[b.bug_id].bug_status}"
        Bug.update_from_rpc(rpc_states[b.bug_id])
      end
      flash_message :alert, warnings.join('<br/>')
    end
    return if ok_bugs.empty?

    def et_comment(bug, new_state)
      comment = params["bz_#{bug.bug_id}_comment"]
      "\n__div_bug_states_separator\n" +
        "bug #{bug.bug_id} changed from #{bug.bug_status} to #{new_state}\n" +
        comment +
        "\n__end_div\n"
    end

    def bug_comment(bug, new_state)
      comment = params["bz_#{bug.bug_id}_comment"]

      "Bug report changed from #{bug.bug_status} to #{new_state} status by the Errata System: \n" +
        "Advisory #{@errata.fulladvisory}: \n" +
        "Changed by: #{current_user.to_s}\n" +
        "http://errata.devel.redhat.com/advisory/#{@errata.id}\n\n#{comment}"
    end

    errata_comment = ''
    ok_bugs.each do |b|
      new_state = newstates[b.bug_id.to_s]
      update_succeeded = rpc.changeStatus(b.bug_id, new_state, bug_comment(b, new_state))
      unless update_succeeded
        flash_message :error, "Failure occurred updating bug #{b.bug_id} from #{b.bug_status} to #{new_state}."
        return
      end
      errata_comment += et_comment(b, new_state)
      # Neccessary since bugs are loaded via joins
      # See: http://api.rubyonrails.org/classes/ActiveRecord/Base.html#M001068
      update_bug = Bug.find(b.id)
      update_bug.bug_status = new_state
      update_bug.save
    end
  ensure
    @errata.comments.create(:text => errata_comment) unless errata_comment.blank?
  end
end
