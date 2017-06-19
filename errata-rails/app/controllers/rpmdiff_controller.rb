# :api-category: Legacy
class RpmdiffController < ApplicationController
  include ApplicationHelper, ReplaceHtml
  include SharedApi::ErrataBuilds

  # This disallows direct access to the reschedule methods; you must first visit
  # one of the :except methods first.
  skip_before_filter :readonly_restricted
  verify :except => [
    :index,
    :list,
    :control,
    :show,
    :waivers_by_package,
    :waivers_by_test,
    :waivers_for_errata,
    :manage_waivers,
    :result,
    :create_autowaive_rule,
    :show_autowaive_rule,
    :manage_autowaive_rule,
    :clone_single_autowaive_rule,
    :list_autowaive_rules],
  :method => :post,
  :redirect_to => { :action => :list }
  before_filter :find_errata, :only => [:list, :reschedule_all, :reschedule_one, :waivers_for_errata, :manage_waivers, :request_waivers, :ack_waivers]
  before_filter :can_reschedule, :only => [:list, :reschedule_all, :reschedule_one]
  before_filter :set_index_nav, :except => [:list, :show]
  before_filter :admin_can_access, :only => [:delete_autowaive_rule]

  # This should not be necessary, yet in my test environment, it was -- jwl.
  helper :rpmdiff
  use_helper_method :compared_to_text

  def index
    redirect_to :action => 'control'
  end

  #
  # Fetch the current RPMDiff runs for an advisory.
  #
  # :api-url: /advisory/{id}/rpmdiff_runs.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # [
  #   {
  #     "rpmdiff_run": {
  #       "last_good_run_id": null,
  #       "new_version": "2.3.3-5.el5",
  #       "obsolete": 0,
  #       "errata_file_id": null,
  #       "errata_brew_mapping_id": 35876,
  #       "overall_score": 2,
  #       "brew_rpm_id": 2322519,
  #       "errata_id": 13391,
  #       "run_id": 62299,
  #       "package_path": "/mnt/redhat/brewroot/packages/postfix/2.3.3/5.el5/src/postfix-2.3.3-5.el5.src.rpm",
  #       "errata_nr": "2012:13391",
  #       "old_version": "2.3.3-2.3.el5_6",
  #       "person": "jskarvad@redhat.com",
  #       "package_id": 482,
  #       "brew_build_id": 219152,
  #       "package_name": "postfix",
  #       "run_date": "2012-06-27T12:54:09Z",
  #       "variant": "5Server"
  #     }
  #   }
  # ]
  # ````
  #
  # The following is the list of the "overall_score" value. The items 'PASSED',
  # 'INFO', 'WAIVED', 'NEEDS_INSPECTION' and 'FAILED' show the maximum score
  #  for any of the completed run's results for rpmdiff tests, and the
  #  other 3 items 'TEST_IN_PROGRESS', 'UNPACKING_FILES' and 'QUEUED_FOR_TEST'
  #  indicate that the rpmdiff tests are in progress.
  #
  # Score    Item
  # -----    ----
  # -1       DUPLICATE
  # 0        PASSED
  # 1        INFO
  # 2        WAIVED
  # 3        NEEDS_INSPECTION
  # 4        FAILED
  # 498      TEST_IN_PROGRESS
  # 499      UNPACKING_FILES
  # 500      QUEUED_FOR_TEST
  #
  def list
    @user = current_user
    extra_javascript 'view_section'
    set_index_nav
    set_page_title "RPMDiff Runs for " + @errata.shortadvisory
    respond_to do |format|
      format.html
      format.xml  { render :layout => false }
      format.json { render :layout => false, :json => @errata.rpmdiff_runs.to_json }
    end
  end

  def result
    extra_javascript 'waive'
    @current_result = RpmdiffResult.find params[:id]
  end

  def reschedule_all
    RpmdiffRun.invalidate_all_runs(@errata)
    schedule_rpmdiff_runs(@errata)

    show_notice("RPMDiff Runs Rescheduled For Errata #{@errata.shortadvisory}")
    redirect_to :action => :list, :id => @errata
  end

  def reschedule_one
    old_run = RpmdiffRun.find(params[:run_id])
    begin
      new_run = old_run.reschedule(current_user.login_name)
      show_notice("RPMDiff run #{old_run.id} has been obsoleted. New run #{new_run.id} scheduled.")
    rescue ActiveRecord::RecordInvalid => error
      show_alert(error.message)
    end
    redirect_to :action => :list, :id => @errata
  end

  def show
    extra_javascript 'waive'
    @current_run = RpmdiffRun.find(params[:id], :include => [:errata])
    @errata = @current_run.errata
    set_index_nav

    if params['result_id']
      res_id = params['result_id'].to_i
      @current_result = @current_run.rpmdiff_results.detect {|r| r.id == res_id}
    end
    @current_result = @current_run.rpmdiff_results.first unless @current_result

    @can_waive = true if @current_result && @current_result.can_waive?(current_user)
    @can_waive = true if current_user.in_role?('secalert')

    set_page_title "Test results for #{@errata.fulladvisory}: #{compared_to_text(@current_run)}" # (Not actually used??)
  end

  def control
    @inprogress = RpmdiffRun.find(:all,
                                  :conditions => ["overall_score in (?) AND obsolete = 0",
                                                  [RpmdiffScore::TEST_IN_PROGRESS, RpmdiffScore::UNPACKING_FILES]],
                                  :order => 'run_date DESC')
    @pending = RpmdiffRun.find(:all,
                               :conditions => ["overall_score = ? AND obsolete = 0", RpmdiffScore::QUEUED_FOR_TEST],
                               :order => 'run_date DESC')
    @lasttests = RpmdiffRun.find(:all,
                                 :conditions => ["overall_score != ?", RpmdiffScore::DUPLICATE],
                                 :order => 'run_date DESC',
                                 :limit => 10)
    @lastfails = RpmdiffRun.find(:all,
                                 :conditions => "obsolete = 0 and overall_score > 2",
                                 :order => 'run_date DESC',
                                 :limit => 10)


    set_page_title "RPMDiff Control Center"
  end

  # method should be invoked from :show
  def add_comment
    result = RpmdiffResult.find(params[:id])
    result.rpmdiff_waivers.create(:user => current_user,
                                  :description => params['comment'],
                                  :old_result => result.score)

    redirect_to :action => 'show', :id => result.rpmdiff_run.run_id, :result_id => params[:id]
  end

  # Backend routines
  # method should be invoked from :show
  def unwaive
    old_waiver_score = RpmdiffWaiver.find(:first,
                                          :select => 'old_result',
                                          :order => 'waiver_id DESC',
                                          :conditions => ['result_id = ?', params[:result_id]]).old_result
    waive_unwaive(:description => params[:unwaive_text],
                  :score => old_waiver_score)
  end

  def waive
    waive_unwaive(:description => params[:waive_text],
                  :score => RpmdiffScore::WAIVED)
  end

  def waivers_by_package
    extra_javascript 'change_handler'
    if request.post?
      id = params[:package][:id]
      redirect_to :action => :waivers_by_package, :id => id
    else
      id = params[:id]
    end
    @packages = Package.find(:all,
                             :conditions => ['id in (select package_id from rpmdiff_waivers)'],
                             :order => 'name')
    if id
      @package = Package.find(id)
    else
      @package = @packages.first
    end

    @waivers = RpmdiffWaiver.find(:all,
                                  :conditions =>
                                  ['old_result != 2 and rpmdiff_waivers.package_id = ?',
                                   @package],
                                  :include => [:user, :rpmdiff_run, :rpmdiff_test, :rpmdiff_result],
                                  :order => 'waive_date desc')
    set_page_title "RPMDiff Waiver History for #{@package.name}"
  end

  def waivers_by_test
    extra_javascript 'change_handler'
    if request.post?
      id = params[:test][:id]
      redirect_to :action => :waivers_by_test, :id => id
    else
      id = params[:id]
    end
    @tests = RpmdiffTest.find(:all,
                             :order => 'description')
    if id
      @test = RpmdiffTest.find(id)
    else
      @test = @tests.first
    end

    @waivers = RpmdiffWaiver.find(:all,
                                  :conditions =>
                                  ['old_result != 2 and rpmdiff_waivers.test_id = ?',
                                   @test],
                                  :include => [:user, :rpmdiff_run, :rpmdiff_result],
                                  :order => 'waive_date desc')
    set_page_title "RPMDiff Waiver History for #{@test.description}"
  end

  def waivers_for_errata
    set_page_title "RPMDiff Waiver History for " + @errata.shortadvisory
    @waivers = RpmdiffWaiver.waivers_for_errata(@errata)
  end

  def manage_waivers
    extra_javascript 'manage_waivers'
    extra_stylesheet 'manage_waivers'
    set_page_title "Manage RPMDiff Waivers for #{@errata.shortadvisory}"

    runs = @errata.rpmdiff_runs.includes(:rpmdiff_results).current

    # the thought here is that it makes sense to display all the results for the same test
    # next to each other so all failures of a particular type can be easily reviewed together;
    # and within a particular test, it's nicer to have the packages in a predictable order
    # than at random.
    rpmdiff_sort_by = lambda{|r| [r.rpmdiff_test.description, r.rpmdiff_run.package.name]}

    all_waivable = runs.map{|run| run.rpmdiff_results.includes(:rpmdiff_score,:rpmdiff_test).waivable}.flatten.compact.sort_by(&rpmdiff_sort_by)
    @waivable_results = {}
    (@waivable_results[:by_self],@waivable_results[:by_other]) = all_waivable.partition(&:can_waive?)

    all_ackable = runs.map{|run| run.rpmdiff_results.includes(:rpmdiff_score,:rpmdiff_test,:rpmdiff_waivers).where(:score => RpmdiffScore::WAIVED)}\
      .flatten.sort_by(&rpmdiff_sort_by).map{|res| res.rpmdiff_waivers.last}.reject{|w| w.acked?}
    @ackable_waivers = {}
    (@ackable_waivers[:by_self],@ackable_waivers[:by_other]) = all_ackable.partition(&:can_ack?)

    # for everything to be displayed, get the waiver history as well; if QE have previously nacked waivers for some runs,
    # this is where it will show up
    history = RpmdiffWaiver.where(:result_id => [all_waivable.map(&:id), all_ackable.map(&:result_id)].flatten).order('waiver_id ASC')
    history = history.group_by(&:result_id)
    @waiver_history = history
  end

  def request_waivers
    errors = []
    waived_count = 0
    RpmdiffResult.transaction do
      (params['request_waiver']||[]).each do |id,request|
        next unless request.to_bool
        result = RpmdiffResult.find(id)

        unless result.can_waive?(current_user)
          errors << "You do not have permission to waive result #{id}."
          next
        end

        old_score = result.rpmdiff_score
        provided_score = params['score'][id].to_i
        unless old_score.id == provided_score
          errors << "Result #{id} changed from #{RpmdiffScore.find(provided_score).description} to #{old_score.description} " +
                    "after the form was loaded. Please review the results again before submitting."
          next
        end

        result.score = RpmdiffScore::WAIVED
        result.save
        result.rpmdiff_waivers.create(:user => current_user,
                                      :description => join_waive_text(params['waive_text'][id], params['waive_text_shared']),
                                      :old_result => old_score.id)
        waived_count += 1
      end
    end

    unless errors.empty?
      show_error(errors)
    end
    if waived_count == 0
      # errors are sufficient if any were displayed.
      # otherwise, hint to the user that nothing happened.
      show_alert('No tests were selected to waive!') if errors.empty?
    else
      show_notice("Requested waivers for #{n_thing_or_things(waived_count, 'test')}.")
    end

    redirect_to :action => 'manage_waivers', :id => @errata.id
  end

  def ack_waivers
    errors = []
    approve_count = 0
    reject_count = 0
    ack_text = params.fetch('ack_text', {})

    RpmdiffWaiver.transaction do
    (params['ack']||[]).each do |id,val|
        next if val.blank?

        unless %w{approve reject}.include?(val)
          errors << "waiver #{id}: invalid operation #{val}"
          next
        end

        waiver = RpmdiffWaiver.find(id)

        text = join_waive_text(
          ack_text[id],
          params['ack_text_shared'] )

        if val == 'approve'
          if !waiver.can_ack?
            errors << "You do not have permission to approve waiver #{id}."
            next
          end
          waiver.ack!(:text => text)
          approve_count += 1
        elsif val == 'reject'
          if !waiver.can_nack?
            errors << "You do not have permission to reject waiver #{id}."
            next
          end
          if text.blank?
            errors << "An explanation must be provided to reject waiver #{id}."
            next
          end
          waiver.nack!(:text => text)
          reject_count += 1
        end
      end
    end

    unless errors.empty?
      show_error(errors)
    end
    if approve_count != 0 || reject_count != 0
      notice = []
      notice << "Approved #{n_thing_or_things(approve_count, 'waiver')}." if approve_count > 0
      notice << "Rejected #{n_thing_or_things(reject_count, 'waiver')}." if reject_count > 0
      show_notice(notice)
    elsif errors.empty?
      # no errors, no acks, no nacks - hint to the user that nothing happened
      show_alert('No waivers were selected to approve or reject!')
    end

    redirect_to :action => 'manage_waivers', :id => @errata.id
  end

  def show_autowaive_rule
    @autowaive_rule = find_autowaive_rule
    if @autowaive_rule
      @current_result = find_rpmdiff_result_detail(@autowaive_rule.created_from_rpmdiff_result_detail_id).try(:rpmdiff_result)
    end
    set_page_title "RPMDiff Autowaive Rule"
  end

  def create_autowaive_rule
    unless current_user.can_create_autowaive_rule?
      respond_to do |format|
        format.html { render :template => 'rpmdiff/_alert_user_no_permission_to_create_autowaive_rule' }
      end
    end

    data = {}
    detail = find_rpmdiff_result_detail(params[:result_detail_id])

    if detail
      result = detail.rpmdiff_result
      run = result.rpmdiff_run
      data = {
        :package_name => run.package_name,
        :subpackage => detail.subpackage,
        :test_id => result.test_id,
        :content_pattern => RpmdiffAutowaiveRule.content_to_regexp(detail.content),
        :product_versions => [run.errata_brew_mapping.product_version],
        :score => detail.score,
        :created_from_rpmdiff_result_detail_id => detail.result_detail_id,
      }
    end
    @autowaive_rule = RpmdiffAutowaiveRule.new(data)
    # can_activate as default
    @can_activate = true
    if @autowaive_rule.created_from_rpmdiff_result_detail_id
      @can_activate = @autowaive_rule.can_activate?
      @current_result = result
      @errata = run.errata
    end
    set_page_title "New Autowaive Rule"
  end

  def manage_autowaive_rule
    success_notice = "Changes applied."
    @autowaive_rule = find_autowaive_rule
    # Create a new rule, if this request is coming from :create_autowaive_rule
    if @autowaive_rule.nil? && params.has_key?(:rpmdiff_autowaive_rule)
      @autowaive_rule = RpmdiffAutowaiveRule.new
    end

    set_page_title "Edit Autowaiver"

    if request.post? or request.put?
      data = {}
      if user_activates_autowaive_rule?(current_user, @autowaive_rule, params[:rpmdiff_autowaive_rule])
        data = {:approved_by => current_user, :approved_at => Time.now.utc}
      end

      if @autowaive_rule.update_attributes(params[:rpmdiff_autowaive_rule].merge(data))
        redirect_to_success_action = get_redirect_to_success_action
        flash_message :notice, success_notice
        return redirect_to redirect_to_success_action
      else
        flash_message :error, "Error editing autowaiver: #{@autowaive_rule.errors.full_messages.join(', ')}"
      end
    end

    if @autowaive_rule
      detail = find_rpmdiff_result_detail(@autowaive_rule.created_from_rpmdiff_result_detail_id)
    end
    # can_activate as default
    @can_activate = true
    if detail
      result = detail.rpmdiff_result
      run = result.rpmdiff_run
      @can_activate =  @autowaive_rule.can_activate?
      @current_result = result
      @errata = run.errata
    end

    respond_to do |format|
      format.html { render :template => 'rpmdiff/create_autowaive_rule' }
    end
  end

  # clone an autowaive rule base on an existing rule
  # when user has the permission to create autowaive rule
  # also has the permission to clone
  def clone_single_autowaive_rule
    # if the current user has no permission to clone
    # redirect to view autowaive rule page, and show no permission to clone warning msg
    unless current_user.can_create_autowaive_rule?
      flash_message :alert, "You don't have permission to clone an autowaive rule"
      return redirect_to :action => :show_autowaive_rule, :id => params[:id]
    end

    set_page_title "Clone Autowaiver"

    @autowaive_rule = find_autowaive_rule

    if @autowaive_rule
      # the new rule should be inactive as default
      @autowaive_rule.active = false

      detail = find_rpmdiff_result_detail(@autowaive_rule.created_from_rpmdiff_result_detail_id)
    end
    # can_activate as default
    @can_activate = true
    if detail
      result = detail.rpmdiff_result
      run = result.rpmdiff_run
      @can_activate =  @autowaive_rule.can_activate?
      @current_result = result
      @errata = run.errata
    end

    respond_to do |format|
      format.html { render :template => 'rpmdiff/create_autowaive_rule' }
    end
  end

  def list_autowaive_rules
    set_page_title "RPMDiff Autowaivers"
    @packages = RpmdiffAutowaiveRule.select(:package_name).order(:package_name).collect{|n| [n.package_name, n.package_name]}.uniq
    @subpackages = RpmdiffAutowaiveRule.select(:subpackage).order(:subpackage).collect{|n| [n.subpackage, n.subpackage]}.uniq
    @tests = RpmdiffAutowaiveRule.select(:test_id).collect{|r| [r.rpmdiff_test.description, r.rpmdiff_test.test_id]}.uniq
    @product_versions = RpmdiffAutowaiveProductVersion.all.map{|p| [p.product_version.name, p.product_version.id]}.sort().uniq()
    @autowaive_rules = RpmdiffAutowaiveRule
    @autowaive_rules = @autowaive_rules.where('package_name' => params[:package]) if params[:package].present?
    @autowaive_rules = @autowaive_rules.where('test_id' => params[:test]) if params[:test].present?
    @autowaive_rules = @autowaive_rules.joins(:product_versions).where(:rpmdiff_autowaive_product_versions => {:product_version_id => params[:product_version]}) if params[:product_version].present?
    if params[:enabled].present?
      if params[:enabled] == "true"
        @autowaive_rules = @autowaive_rules.where('active' => true)
      else
        @autowaive_rules = @autowaive_rules.where('active is null or active = ?', false)
      end
    end
    @autowaive_rules = @autowaive_rules.paginate(
      :page => params[:page], :order => 'created_at DESC')
  end

  protected

  def find_autowaive_rule
    RpmdiffAutowaiveRule.find_by_autowaive_rule_id(params[:id])
  end

  def find_rpmdiff_result_detail(result_detail_id)
    return nil unless result_detail_id
    RpmdiffResultDetail.find_by_result_detail_id(result_detail_id)
  end

  def admin_can_access
    unless current_user.can_manage_autowaive_rule?
      flash_message :error, "You don't have the necessary role to access this resource."
      return redirect_to :action => :list_autowaive_rules
    end
  end

  def can_reschedule
    @reschedule_permitted = current_user.in_role?('qa', 'devel', 'releng', 'secalert') && State.open_state?(@errata.status)
  end

  def get_secondary_nav
    return get_individual_errata_nav if %w[list show waivers_for_errata manage_waivers].include? params[:action]
    [
      { :name => 'RPMDiff Control',    :controller => :rpmdiff, :action => :control            },
      { :name => 'Waivers By Package', :controller => :rpmdiff, :action => :waivers_by_package },
      { :name => 'Waivers By Test',    :controller => :rpmdiff, :action => :waivers_by_test    },
      { :name => 'Autowaivers',        :controller => :rpmdiff, :action => :list_autowaive_rules},
    ].compact
  end

  private
  def show_notice(messages)
    set_flash_message(:notice, messages)
  end

  def show_alert(messages)
    set_flash_message(:alert, messages)
  end

  def show_error(messages)
    set_flash_message(:error, messages)
  end

  def join_waive_text(*text)
    text.reject(&:blank?).map(&:strip).reject do |t|
      # protect against submitting boilerplate
      ['these changes are ok because', 'this change is ok because'].include?(t.downcase)
    end.join("\n")
  end

  def get_redirect_to_success_action
    result = {:action => :list_autowaive_rules}

    rpmdiff_result_detail = find_rpmdiff_result_detail(params[:result_detail_id])
    if rpmdiff_result_detail
      rpmdiff_result = rpmdiff_result_detail.rpmdiff_result

      result = {:action => :show,
        :id => rpmdiff_result.rpmdiff_run.id,
        :result_id => rpmdiff_result.id
      }
    end
    result
  end
  helper_method :get_redirect_to_success_action

  def user_activates_autowaive_rule?(user, autowaive_rule, params)
    params.has_key?(:active) \
      && !autowaive_rule.active \
      && params[:active].to_bool \
      && user.can_edit_autowaive_rule? \
      && autowaive_rule.can_activate?
  end

  def waive_unwaive(args)
    result = RpmdiffResult.find(params[:id])
    if args[:score] == RpmdiffScore::WAIVED && !result.can_waive?(current_user)
      show_error("You do not have permission to change this result.")
      redirect_to :action => 'show', :id => result.rpmdiff_run.run_id, :result_id => params[:id]
      return
    end
    old_result = result.score
    result.score = args[:score]
    ActiveRecord::Base.transaction do
      begin
        result.rpmdiff_waivers.create!(:user => current_user,
                                       :description => args[:description],
                                       :old_result => old_result)
        result.save!
      rescue => error
        logger.error error
        show_error(error.message)
        raise ActiveRecord::Rollback
      end
    end

    redirect_to :action => :show, :id => result.rpmdiff_run.run_id, :result_id => params[:id]
  end

end
