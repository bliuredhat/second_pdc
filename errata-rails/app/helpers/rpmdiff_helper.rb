module RpmdiffHelper
  include RpmdiffTableHelper

  # Used to alternate colors when formatting templates
  $count = 0
  @reschedule_permitted = false

  def max_len_of_autowaive_rule_subpackage_name
    RpmdiffAutowaiveRule.columns_hash['subpackage'].limit
  end

  def list_autowaive_rules_actions(autowaive_rule, current_user)
    [
      (link_to(
        'Edit',
        url_for(:controller => :rpmdiff, :action => :manage_autowaive_rule, :id => autowaive_rule.id),
        :class => 'btn btn-mini') if (
        current_user.can_edit_autowaive_rule?)
      ),
      (link_to(
        'Clone',
        url_for(:controller => :rpmdiff, :action => :clone_single_autowaive_rule, :id => autowaive_rule.id),
        :class => 'btn btn-mini') if (
        current_user.can_create_autowaive_rule?)
      ),
    ].compact.join.html_safe
  end

  def sortable_time_ago_with_user(timestamp, user)
    return tablesort_helper('-', 0, :title => '') unless timestamp
    content = "#{time_ago_future_or_past(timestamp)}<br />#{nice_mailto_link(user)}".html_safe
    tablesort_helper(content, timestamp.to_i, :title => timestamp.utc.to_s)
  end

  def result_link(result)
    link_to(result.rpmdiff_test.description, {:action => :show, :id => result.run_id, :result_id => result.result_id})
  end

  # Generate hidden fields to be added to a rpmdiff form
  def hidden_form_elements(errata = nil, rpmdiff_run = nil, rpmdiff_result = nil)
    elements = ''

    if (errata) then
      elements += hidden_field_tag 'errata_id', errata.id.to_s
    end

    if (rpmdiff_run) then
      elements += hidden_field_tag 'run_id', rpmdiff_run.run_id.to_s
    end

    if (rpmdiff_result) then
      elements += hidden_field_tag 'test_id', rpmdiff_result.rpmdiff_test.test_id.to_s
      elements += hidden_field_tag 'result_id', rpmdiff_result.result_id.to_s
    end

    return elements.html_safe
  end


  # Note: rpmdiff_list_header and rpmdiff_list_row are related methods
  #  and should be modified simultaneously

  # Generate a header to appear at the top of a rpmdiff list table
  def rpmdiff_list_header(with_reschedule = false)
    headers = [
      tablesort_heading_custom_sort_numeric('ID'),
      'Status',
      'Package',
      'Old',
      'New',
      'Path',
      tablesort_heading_custom_sort_numeric('Date'),
      'Person']
    headers << tablesort_heading_no_sort('Reschedule') if (
      with_reschedule && @reschedule_permitted)
    headers
  end

  # Generate a row to appear in a rpmdiff list table
  def rpmdiff_list_row(run, with_reschedule = false)
    #
    # Note the second row, which uses a hash to set a fixed styling for the
    # row.
    #
    row = [
      tablesort_helper(
        link_to_unless(run.rpmdiff_score.description == 'Unpacking files' || run.rpmdiff_score.description == 'Queued for test',
          run.run_id.to_s, :action => 'show', :id => run.run_id) + ' ' + non_current_indicator(run),
        run.run_id),
      {:content => link_to_unless(run.rpmdiff_score.description == 'Unpacking files' || run.rpmdiff_score.description == 'Queued for test', run.rpmdiff_score.description, :action => 'show', :id =>  run.run_id), :options => {:style => "background-color: " + run.rpmdiff_score.html_color}},
      run.package_name,
      (run.old_version == 'NEW_PACKAGE' ? '-' : run.old_version),
      run.new_version,
      {:content=>run.package_path,:options=>{:style=>'font-size:75%;'}},
      sortable_time_ago_in_words(run.run_date),
      display_person(run),
    ]
    if (with_reschedule && @reschedule_permitted)
      resched_tag =
        link_to("Reschedule", { :action => 'reschedule_one', :run_id => run.run_id, :id => @errata.id },
                :confirm => "Reschedule run #{run.id} for #{@errata.shortadvisory}...\nAre you sure?", :method => :post, :class=>'btn btn-mini')
      row << resched_tag
    end
    row
  end

  def display_person(run)
    %{<a href="mailto:#{run.person}">#{run.person.sub(/@redhat.com$/i, '')}</a>}.html_safe
  end

  def non_current_indicator(run)
    if run.obsolete?
      '<span class="tiny label">OBSOLETE</span>'.html_safe
    elsif run.duplicate?
      '<span class="tiny label">DUPLICATE</span>'.html_safe
    else
      ''
    end
  end

  def rpmdiff_runs(runs, type, with_reschedule, collapsed)
    return if runs.empty?
    content_tag(:div, :class=>"section_container #{'section_container_collapsed' if collapsed}") do
      render("shared/view_section_heading", {
        :name => type.downcase,
        :title => "#{type} Runs (#{runs.length})",
        :title_note => ("(Click to expand)" if collapsed),
      }) +
      content_tag(:div, :class=>"section_content") do
        render("shared/bz_table", {
           :headers => rpmdiff_list_header(with_reschedule),
           :row_items => runs,
           :func => lambda { |run| rpmdiff_list_row(run, with_reschedule) },
           :extra_class => 'compact',
        })
      end
    end
  end

  def current_runs
    current = @errata.rpmdiff_runs.select {|r| r.current? }
    rpmdiff_runs(current, 'Current', true, false)
  end

  def duplicate_runs
    dups = @errata.rpmdiff_runs.select {|r| r.duplicate? }
    rpmdiff_runs(dups, 'Duplicate', false, true)
  end

  def obsolete_runs
    obs = @errata.rpmdiff_runs.select {|r| r.obsolete? }
    rpmdiff_runs(obs, 'Obsolete', false, true)
  end


  # Note: rpmdiff_control_header and rpmdiff_control_row are related methods
  #  and should be modified simultaneously

  # Generate a header to appear at the top of a rpmdiff control table
  def rpmdiff_control_header
    '<tr><thead>
     <td>Run</td>
     <td>Score</td>
     <td>Package</td>
     <td>Old</td>
     <td>New</td>
     <td>Advisory</td>
     <td>Owner</td>
     <td>Date</td>
     </thead></tr>'.html_safe
  end

  # Generate a row to appear in a rpmdiff control table
  def rpmdiff_control_row(run)
    $count += 1
    style = ($count % 2 == 0 ? 'bz_even' : 'bz_odd');
    row =
      '<tr class=\'' + style + '\'>
       <td>' + link_to(run.run_id, :action => 'show', :id => run.run_id) + '</td>
       <td style="background-color:' + run.rpmdiff_score.html_color + ';">'+ run.rpmdiff_score.description + '</td>
       <td>' + run.package_name + '</td>
       <td><span class="light">' + (run.old_version == 'NEW_PACKAGE' ? '-' : run.old_version) + '</span></td>
       <td>' + run.new_version + '</td>
       <td>' + link_to_if(run.errata_nr, run.errata_nr,
                          :controller => 'errata', :action => 'info',
                          :id => run.errata_id).to_s + '</td>
       <td>' + run.person + '</td>
       <td>' + run.run_date.strftime("%Y-%m-%d %H:%M") + '</td>
       </tr>'
    row.html_safe
  end

  def rt_ticket_mail_to(email_address, link_text, rpmdiff_result, errata)
    mail_to(email_address, link_text,
      :subject => "RPMDiff waive request for #{rpmdiff_result.rpmdiff_run.package_name} in #{errata.advisory_name}",
      :body => [
        # Advisory details and link
        "Advisory: #{errata.fulladvisory} - #{errata.synopsis}",
        "#{get_full_advisory_link(errata)}",
        "",
        # Test result details and link
        "Results for #{compared_to_text(rpmdiff_result.rpmdiff_run)}",
        "Test: #{rpmdiff_result.rpmdiff_test.description}",
        get_current_url,
        "",
        "Reason waiver is required:",
        "[REPLACE THIS TEXT AND EXPLAIN WHY WAIVER IS REQUIRED]",
        ""
      ].join("\n")
    )
  end

  def active_rule_rt_ticket_mail_to(email_address, link_text, rpmdiff_result, errata)
    mail_to(email_address, link_text,
      :subject => "Activate RPMDiff autowaive rule request for #{rpmdiff_result.rpmdiff_run.package_name} in #{errata.advisory_name}",
      :body => [
        # Advisory details and link
        "Advisory: #{errata.fulladvisory} - #{errata.synopsis}",
        "#{get_full_advisory_link(errata)}",
        "",
        # Test result details and link
        "Results for #{compared_to_text(rpmdiff_result.rpmdiff_run)}",
        "Test: #{rpmdiff_result.rpmdiff_test.description}",
        "#{get_rpmdiff_result_link(rpmdiff_result)}",
        "",
        # autowaive rule link
        "Autowaive rule link (if not correct, please change it)",
        get_current_url,
        "",
        "Reason required:",
        "[REPLACE THIS TEXT AND EXPLAIN WHY THE RULE IS REQUIRED]",
        ""
      ].join("\n")
    )
  end

  def compared_to_text(run)
    "#{run.package_name}-#{run.new_version} compared to #{run.package_name}-#{run.old_version}"
  end

  def show_create_autowaive_link?(user, score)
    user.can_create_autowaive_rule? && RpmdiffScore.for_autowaiving_rules.any? { |x| x.id == score }
  end

  def show_matched_autowaive_rule_link?(detail)
    detail.score == RpmdiffScore::WAIVED && detail.matched_rule
  end

  def has_no_results_to_waive?(waivable_results, ackable_waivers)
    waivable_results.merge(ackable_waivers).values_at(:by_self, :by_other).flatten.empty?
  end

end
