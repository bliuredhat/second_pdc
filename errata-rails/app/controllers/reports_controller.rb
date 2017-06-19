class ReportsController < ApplicationController
  before_filter :set_index_nav
  def index
    if current_user.can_see_managed_errata?
      redirect_to :action => :managed_errata
    else
      redirect_to :action => :dashboard
    end
  end
  
  def dashboard
    extra_javascript 'reports_dashboard'
    set_page_title 'QA Dashboard'

    # Open Errata for each QA team member
    @user_stats = Hash.new {|hash, key| hash[key] = Hash.new(0)}
    @group_stats = Hash.new {|hash, key| hash[key] = Hash.new(0)}
    
    open_states = State.open_states.collect{|s| "#{s.to_s}"}
    errata = Errata.find(:all, :conditions => ["is_valid = 1 AND status in (?)", open_states],
                         :include => [:assigned_to, :release, :product, :quality_responsibility],
                         :order => 'assigned_to_id')

    errata.each do |e|
      user = e.assigned_to
      unless user.login_name == MAIL['default_docs_owner'] || user.login_name == MAIL['default_qa_user']
        @user_stats[user][e.status.to_s] += 1
      end
      @group_stats[e.quality_responsibility][e.status.to_s] += 1
    end

    # "Errata Needing Attention"
    @max = 0
    @errata_stats = Hash.new {  |hash, key| hash[key] = []}

    # Make a hash of blocked errata grouped by their status
    Errata.active.each do |e|
      next unless e.is_blocked?

      updated = DateTime.new(e.status_updated_at.year,
                             e.status_updated_at.month,
                             e.status_updated_at.day,
                             e.status_updated_at.hour,
                             e.status_updated_at.min)

      age = (DateTime.now - updated).to_i
      @errata_stats[e.status].push({:errata => e, :age => "#{age} days"})
      @max = @errata_stats[e.status].length if @errata_stats[e.status].length > @max
    end


    # getRPMDiffFailures
    @rpmdiff_failures = []
    errata_query = ""

    runs = RpmdiffRun.find(:all,
                           :conditions => ["obsolete = 0 and overall_score in (?) and rpmdiff_runs.errata_id in (select id from errata_main where is_valid = 1 and status = 'NEW_FILES' and issue_date > ?)",
                                           [RpmdiffScore::NEEDS_INSPECTION, RpmdiffScore::FAILED], Time.now.months_ago(3)],
                           :include => [:errata])


    runs.each do |r|
      @rpmdiff_failures.push({:errata => r.errata, :run => r})
    end

    @max = @rpmdiff_failures.length if @rpmdiff_failures.length > @max
  end

  def errata_by_engineering_group
    @responsible = :package_owner
    set_org_errata
    set_page_title 'Advisories by Engineering Group'
  end

  def errata_by_qe_group
    @responsible = :assigned_to
    set_page_title 'Advisories by QE Group'

    conditions = ['is_valid = 1 and status not in (?)', ['SHIPPED_LIVE','DROPPED_NO_SHIP']]
    include = [:release, :product, :bugs, :assigned_to, :quality_responsibility]
    
    errata = Errata.find(:all, :conditions => conditions, :include => include)
    @org_errata = HashList.new    
    errata.each do |e|
      class << e.quality_responsibility
        def manager
          return default_owner
        end
      end
      @org_errata[e.quality_responsibility] << e
    end
    
  end

  def managed_errata
    user = User.find_by_name(params[:id]) if params[:id]
    user = current_user unless user
   
    unless user.can_see_managed_errata?
      redirect_to :action => :errata_by_engineering_group
     return
    end
    if user.in_role?('devel')
      @responsible = :package_owner
      @alert_state = 'NEED_DEV'
    else
      @responsible = :assigned_to
      @alert_state = 'NEED_QE'
    end
    
    @user = user
    @org = user.organization
    set_org_errata(user.organization)
    set_page_title "Advisories for #{user.organization.name}"
  end
  
  def scoreboard

    @products = Product.active_products('short_name')
    @product = Product.find(params[:id]) if params[:id]
    @product = Product.find_by_short_name('RHEL') unless @product
    # Errata closures in past 3 months (print group stats)
    @stats = Hash.new {|hash, key| hash[key] = Hash.new(0)}

    @group_totals = Hash.new(0)
    @groups = Release.find(:all, :conditions => ["isactive = 1 and enabled = 1 and product_id = ?", @product])
    @groups << Release.find_by_name('ASYNC')


    activities = ErrataActivity.find(:all,
                                     :conditions => ["added = ? AND created_at >= ? and " +
                                     "errata_id in (select id from errata_main where is_valid = 1 and product_id = ? and " +
                                     "group_id in (?))", 'REL_PREP', Time.now.months_ago(3), @product, @groups],
                                     :order => "created_at desc")
    errata = Hash.new
    Errata.find(activities.collect {|a| a.errata_id}, :include => [:release]).each do |e|
      errata[e.id] = e
    end

    activities.each do |activity|
      week_ending_date = activity.created_at.beginning_of_week + (60*60*24*4)
      key = week_ending_date.year.to_s +
        ' ' +
        (week_ending_date.month < 10 ? "0#{week_ending_date.month.to_s}" : week_ending_date.month.to_s) +
        ' ' +
        (week_ending_date.day < 10 ? "0#{week_ending_date.day.to_s}" : week_ending_date.day.to_s)

      @stats[key][errata[activity.errata_id].release.id] += 1
      @group_totals[errata[activity.errata_id].release.id] += 1
    end
    set_page_title "#{@product.name} Advisories Put in HOLD For Last 3 Months"
  end

  def leaderboard
    set_page_title 'QA Leaderboard'

    # Statistics for open queues (printSummaryStats)
    @group_ids = {}
    @group_scores = Hash.new {|hash, key| hash[key] = Hash.new(0)}
    releases = Release.find(:all, :conditions => "isactive = 1 and enabled = 1")
    releases.each { |r| @group_ids[r.name] = r.id }
    errata = Errata.find(:all,
                         :conditions => ["group_id in (?) and issue_date > ? and assigned_to_id != ?",
                                         releases.collect { |r| r.id}, Time.now.months_ago(3), User.default_qa_user],
                         :include => [:release, :assigned_to])

    user_count = Hash.new(0)
    errata.each do |e|
      @group_scores[e.release.name][e.status] += 1
      user_count[e.assigned_to] += 1
    end

    user_count = user_count.invert
    @test_count = user_count.keys.max
    @most_tests_user = user_count[@test_count]

  end


  def respins
    extra_javascript 'change_handler'
    if request.post?
      id = params[:release][:id]
      resp_id = params[:responsibility][:id]
      if resp_id.to_i > 0
        redirect_to :action => :respins, :id => id, :resp_id => resp_id 
      else
        redirect_to :action => :respins, :id => id
      end
      return
    end

    id = params[:id]
    @resp_id = params[:resp_id]

    @releases = Release.find(:all,
                             :conditions =>
                             'id in (select distinct group_id from errata_main where respin_count > 0)',
                             :order => 'name')

    
    
    @release = Release.url_find(id) if id
    @release = @releases.first unless @release
    conditions = 'respin_count > 0'

    if @resp_id
      conditions = [conditions + " and quality_responsibility_id = ?", QualityResponsibility.url_find(@resp_id)]
    end
    @errata_list = @release.errata.find(:all,
                                        :conditions => conditions,
                                        :include => [:package_owner, :manager, :quality_responsibility],
                                        :order => 'respin_count desc')


    
    @count = 0
    @histogram = Hash.new(0)
    @responsibilities = QualityResponsibility.find(:all, :order => 'name')
    @responsibilities.collect! { |d| [d.name,d.id]}
    @responsibilities.unshift ['---ALL---', -1] 
    
    @respins = HashList.new
    ErrataActivity.find(:all,
                        :conditions => ["what = ? and errata_id in (?)",
                                        'respin', @errata_list]
                        ).each do |r|
      @respins[r.errata_id] << r
    end
    
    @errata_list.each do |e|
      @count += e.respin_count
      reasons = @respins[e.id].collect { |r| r.added }
      reasons.inject(@histogram) {|h,x| h[x] += 1; h}
    end
    
    set_page_title "Advisory Respins for Release #{@release.name}"
    respond_to do |format|
      format.html
      format.xml  { render :layout => false }
    end

  end

  protected
  def get_secondary_nav
    nav = []
    if current_user.can_see_managed_errata?
      nav << { :name => "My Group's Errata", :controller => :reports, :action => :managed_errata}
    end
    nav << { :name => 'QA Dashboard', :controller => :reports, :action => :dashboard}
    nav << { :name => 'Scoreboard', :controller => :reports, :action => :scoreboard}
    nav << { :name => 'Leaderboard', :controller => :reports, :action => :leaderboard}
    nav << { :name => 'Advisories by Engineering Group', :controller => :reports, :action => :errata_by_engineering_group}
    nav << { :name => 'Advisories by QE Group', :controller => :reports, :action => :errata_by_qe_group}
    nav << { :name => 'Respins', :controller => :reports, :action => :respins}
    return nav
  end

  def set_org_errata(parent = nil)
    conditions = ['is_valid = 1 and status not in (?)', ['SHIPPED_LIVE','DROPPED_NO_SHIP']]
    include = [:release, :product, :bugs]
    include << @responsible

    errata = Errata.find(:all, :conditions => conditions, :include => include)
    orgs = { }
    get_orgs(parent).each do |org|
      orgs[org.id] = org
    end

    @org_errata = HashList.new    
    errata.each do |e|
      org_id = e.send(@responsible).try(:user_organization_id)
      next unless orgs.has_key?(org_id)
      @org_errata[orgs[org_id]] << e
    end
  
  end

  
  def get_orgs(parent = nil)
    unless parent
      return UserOrganization.find(:all, :include => [:manager])
    end
    orgs = UserOrganization.all_children(parent)
    orgs << parent
    return orgs
  end
end
