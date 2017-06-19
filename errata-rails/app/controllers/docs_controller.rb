class DocsController < ApplicationController
  include ReplaceHtml
  require 'doc_report'
  ### Interface routines ###
  verify :method => :post,
  :only => [:approve, :change_docs_reviewer, :disapprove, :request_approval],
  :redirect_to => { :action => :list }

  before_filter :find_errata,
  :except => [:list, :update_reviewer, :my_queue, :errata_by_responsibility, :weekly_report]

  before_filter :set_index_nav, :except => [
    :show, :diff_history, :doc_text_info, :draft_release_notes_text, :draft_release_notes_xml
  ]

  before_filter :set_mandatory_only, :only => [:list, :my_queue, :errata_by_responsibility]

  before_filter :use_errata_secondary_nav, :only => [
    :show, :diff_history, :doc_text_info, :draft_release_notes_text, :draft_release_notes_xml
  ]

  skip_before_filter :readonly_restricted, :only => [:show]

  def change_docs_reviewer
    @user = User.current_user
    @advisory = UpdateAdvisoryForm.new(User.current_user, params) if params[:id]
    msg = @advisory.change_docs_reviewer(params[:user_id], params[:comment])
    msg_type = msg.nil? ? :alert : :notice
    msg ||= "Docs reviewer not changed"

    if request.xhr?
      js = flash_notice_js(msg, :type => msg_type)
      js += js_for_template "reviewer_for_#{@errata.id}", 'change_reviewer_ajax', :locals => {:errata => @errata}
      js += "$('#review_#{@errata.id}').data('reviewerId', #{params[:user_id]});"
      js += "$('.modal').modal('hide');"
      render :js => js
      # Called from ajax in docs queue
      # Add a message at the top
    else
      # Normal submit from form in modal in Errata#view or Errata#details
      flash_message msg_type, msg
      back_to   = params[:back_to  ].present? ? params[:back_to  ] : 'view'
      back_to_c = params[:back_to_c].present? ? params[:back_to_c] : 'errata'
      redirect_to :controller => back_to_c, :action => back_to, :id => @errata
    end
  end

  def diff_history
    extra_javascript 'docs'
    @diffs = @errata.text_diffs.find(:all,
                                     :order => 'created_at desc')

    set_page_title "Diff History for #{@errata.fulladvisory} - #{@errata.synopsis}"
  end

  def errata_by_responsibility
    resp = DocsResponsibility.find_by_url_name(params[:id])
    errata = resp.errata.includes(ERRATA_IN_QUEUE_INCLUDES).where(:text_ready => 1, :doc_complete => 0)
    if @mandatory_only
      errata = errata.with_docs_workflow
    end
    @errata = errata.to_a
    @docs_group = Role.docs_people
    extra_javascript %w[docs_queue help_modal]
    prepare_bug_counts
    set_page_title "Documentation Queue for #{resp.name}"
  end

  def list
    set_page_title "Documentation Work Queue"
    @errata = errata_in_queue.to_a
    @docs_group = Role.docs_people.order('realname')
    #@extra_scripts = ['docs_queue', 'docs_sort']
    extra_javascript %w[docs_queue help_modal]

    # Set no_bug_counts=1 to not show bug counts and hence be faster.
    # (Currently undocumented and not exposed via UI)
    @no_bug_counts = params[:no_bug_counts].present?
    prepare_bug_counts unless @no_bug_counts
  end

  def show
    extra_javascript 'docs'
    set_page_title "Advisory Approval &mdash; Documentation"
    @docs_only = params[:nolayout] # If the layout is disabled, we only want to display the doc

    @rpms_by_version_and_arch = Hash.new {
      |hash, key| hash[key] = Hash.new {
        |hash, key| hash[key] = Set.new
      }
    }

    @rpms = Set.new
    @errata.current_files.each do |f|
      rpm = f.brew_rpm
      unless rpm.nil?
        @rpms_by_version_and_arch[f.variant][f.arch] << rpm
        rpm.ftp_path = f.ftp_file.gsub('/ftp/pub/', 'ftp://ftp.redhat.com/pub/')
        @rpms << rpm
      end
    end

  end

  def reroute
    redirect_to :action => :show, :id => @errata
  end

  # (Using render :inline to make it easy to use the helper. Perhaps there's a better way to do that...)
  def approve
    if current_user.can_approve_docs?
      @errata.approve_docs!
      flash_message :notice, render_to_string(:inline => "Documentation for <%= errata_link(@errata) %> APPROVED")
    else
      flash_message :error, "User #{current_user.short_name} not permitted to approve documentation"
    end
    back_to = params[:back_to] || :list
    redirect_to :action => back_to, :controller => :docs, :id => (@errata unless back_to == :list)
  end

  def disapprove
    if current_user.can_approve_docs?
      @errata.disapprove_docs!
      flash_message :notice, render_to_string(:inline => "Documentation for <%= errata_link(@errata) %> DISAPPROVED")
    else
      flash_message :error, "User #{current_user.short_name} not permitted to disapprove documentation"
    end
    back_to = params[:back_to] || :list
    redirect_to :action => back_to, :controller => :docs, :id => (@errata unless back_to == :list)
  end

  def request_approval
    @errata.request_docs_approval!
    flash_message :notice, "Documentation approval has been requested."
    back_to_c = params[:back_to_c] || :errata
    back_to   = params[:back_to]   || :view
    redirect_to :controller => back_to_c, :action => back_to, :id => @errata
  end

  def my_queue
    extra_javascript 'help_modal'
    set_page_title "My Documentation Queue"
    @errata = errata_in_queue.select { |e| e.content.doc_reviewer_id == current_user.id}
    prepare_bug_counts
  end

  #------------------------------------------------------------------------

  # Shows all bugs for an advisory with their doc text and the requires_doc_text flag
  def doc_text_info
    extra_javascript 'docs'
    @bugs = sorted_bugs
  end

  # doc_text_info was previously called tech_note_info so let's be nice and redirect it
  def tech_note_info
    redirect_to :action=>:doc_text_info, :id=>@errata.id
  end

  # Shows draft text for copy/pasting into ET based on the bugs' doc text
  def draft_release_notes_text
    extra_javascript 'docs'
    @hard_wrap = params[:hard_wrap]
    @bugs = sorted_bugs.select(&:doc_text_required?)
  end

  # Shows draft xml for copy/pasting into docbook based on the bugs' doc text
  def draft_release_notes_xml
    extra_javascript 'docs'
    @bugs = sorted_bugs.select(&:doc_text_required?)
  end

  # Reconcile all bugs for an errata and redir back to doc_text_info
  def reconcile_all_bugs
    Bugzilla::Rpc.get_connection.reconcile_bugs(@errata.bugs.map(&:id))
    # Do we need to check the response here for errors?
    flash_message :notice, "Sync performed on all bugs for this advisory"
    redirect_to :action=>:doc_text_info, :id=>@errata.id
  end

  #------------------------------------------------------------------------

  def weekly_report

    if params[:id]
      week_of = Time.at(params[:id].to_i)
    else
      week_of = Time.now
    end

    from = week_of.at_beginning_of_week
    to = from.next_week

    @report = docs_report(from, to)
    @week_nav = from.to_i
    @weeks = weeks_since(TextDiff.find(:first, :order => 'created_at asc').created_at)

    set_page_title "Docs Advisory Activity Summary: #{from.to_date.to_s(:long)} to #{to.to_date.to_s(:long)}"

  end

  private

  #
  # There's a fairly specific order required for bugs in doc_text_info
  #
  def sorted_bugs
    @errata.bugs.sort_by do |bug|
      [
        # First sort by component name, case insensitive (i guess)
        bug.package.name_sort_with_docs_last.downcase,
        # Next by priority, highest first
        bug.priority_order,
      ]
    end
  end

  def set_mandatory_only
    @mandatory_only = params[:mandatory_only] != '0'
  end

  # Because my local mysql insta-crashes if you include bugs with
  # "Mysql2::Error: Lost connection to MySQL server during query"
  ERRATA_IN_QUEUE_INCLUDES = [(:bugs unless Settings.docs_queue_no_include_bugs), :release, {:content => :doc_reviewer}, :docs_responsibility].compact

  def errata_in_queue
    out = Errata.
      includes(ERRATA_IN_QUEUE_INCLUDES).
      order("releases.name, #{State.sort_sql} DESC").
      where(ErrataFilter::DOCS_QUEUE_FILTER_SQL)
    if @mandatory_only
      out = out.with_docs_workflow
    end
    out
  end

  def prepare_bug_counts
    @bug_count_totals = Hash.new{0}
    @errata.each do |e|
      @bug_count_totals[:total]             += e.bugs.length
      @bug_count_totals[:text_not_required] += e.bugs_not_requiring_doc_text.length
      @bug_count_totals[:text_complete]     += e.bugs_with_complete_doc_text.length
      @bug_count_totals[:text_missing]      += e.bugs_missing_doc_text.length
    end
  end

  def get_secondary_nav
    [
      { :name => 'Documentation Queue', :action => :list          },
      { :name => 'My Queue',            :action => :my_queue      },
      { :name => 'Weekly Report',       :action => :weekly_report },
    ] + DocsResponsibility.with_errata_in_docs_queue.map do |docs_resp|
      { :name => docs_resp.name,        :action => :errata_by_responsibility, :id => docs_resp.url_name }
    end
  end

  # Some of these are actually advisory views, so I would like them look like an advisory views
  # Use these advisory tabs instead of the docs queue tabs.
  def use_errata_secondary_nav
    @secondary_nav = get_individual_errata_nav
  end

end
