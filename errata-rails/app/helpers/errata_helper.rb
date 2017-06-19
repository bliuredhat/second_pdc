module ErrataHelper
  include LongShortListHelper
  include ActionView::Helpers::OutputSafetyHelper

  def live_advisory_name(errata)
    return errata.fulladvisory if errata.has_live_id_set?
    year = Time.now.year
    errata_id = LiveAdvisoryName.get_next_live_errata_id(year)
    id_part = sprintf("%.4d", errata_id)
    "#{errata.errata_type}-#{year}:#{id_part}" + "-" + sprintf("%.2d", errata.revision)
  end

  def indent_spacer(level)
    "<b>&nbsp;#{'&nbsp;' * (level-1) * 8}&#x2570;&#x2500;&#x2500;</b>".html_safe
  end

  def dependency_tree_indent(errata, level, opts={})
    if errata.nil?
      # Indicates recursion limit...
      [
        indent_spacer(level),
        'Too much recursion!',
        '<br/>',
      ].join.html_safe
    else
      [
        indent_spacer(level),
        errata_link(errata),
        content_tag(:span, state_display(errata).html_safe, :class=>'tiny', :style=>'padding-left:0.5em;'),
        content_tag(:span, errata.synopsis, :class=>'light',:style=>'padding:0.5em;'),
        (icon_btn_link('Edit', :edit, {:action=>:edit_depends_on, :id=>errata}, :class=>'small') unless opts[:hide_edit_buttons]),
        '<br/>',
      ].compact.join.html_safe
    end
  end

  def push_info_list(errata, type, sub_type = nil)
    br_separated([
      errata.push_blockers_for(sub_type || type),
      push_variant_target_disabled_warning(errata, type)
    ].flatten.compact)
  end

  #
  # Warning if some (but not all) targets do not support push type
  #
  # @param errata [Errata]
  def push_variant_target_disabled_warning(errata, type)
    variants = errata.release_variants.uniq
    unsupported = variants.reject{|v| v.supported_push_types.include?(type)}.sort_by(&:name)
    return if unsupported.none? || unsupported.count == variants.count

    popover = block_render('shared/help_popover') do
      content_tag(:h4, "Push target '#{type}' is not supported by:") +
        content_tag(:ul, unsupported.map{|v| content_tag(:li, link_to(v.name, v))}.join.html_safe)
    end

    ("Push target is not supported by all variants " + popover).html_safe
  end

  def errata_text_area(label, object, method, options = {})
    explanation = explanation_helper(options)

    # Must prevent label_help passing to text_area, it will break rendering
    # (it can contain HTML)
    field_options = options.except(:label_help)

    %{#{errata_text_row(label, options)}<td colspan="3">#{text_area(object, method, field_options)}#{explanation}</td></tr>}.html_safe
  end

  def explanation_helper(options)
    if (explanation_text = options.delete(:explanation_text))
      "<span class='light small'>#{h(explanation_text)}</span>".html_safe
    else
      ""
    end
  end

  def errata_text_field(label, object, method, options = {})
    explanation = explanation_helper(options)

    # Must prevent label_help passing to text_field, it will break rendering
    # (it can contain HTML)
    field_options = options.except(:label_help)

    %{#{errata_text_row(label, options)}<td>#{text_field(object, method, field_options)}#{explanation}</td></tr>}.html_safe
  end

  def make_ftp_url_from_ftp_path(ftp_path)
    ftp_path.
      sub('/ftp/pub/redhat/linux/updates','ftp://updates.redhat.com').
      sub('/ftp/pub/redhat/linux/enterprise','ftp://ftp.redhat.com/pub/redhat/linux/enterprise')
  end

  #
  # TODO:
  #  - move the script and make it generic
  #  - the script should detect the checkbox state
  #  - should probably be a partial instead of a helper
  #
  def errata_text_field_with_choice(label, object, method, opts={})
    choice_name = opts[:choice_name]
    present_now = opts[:present_now] # is it currently on?
    disabled    = opts[:disabled]    # true if inputs should not be usable, e.g. value is locked
    explanation = explanation_helper(opts)
    choice_on = "update_choice_#{choice_name}(this, true);"
    choice_off = "update_choice_#{choice_name}(this, false);"

    %|
      #{errata_text_row(label, opts)}
        <td>
          <script type="text/javascript">
            function update_choice_#{choice_name}(clicked, on) {
              // (This is Prototype not jQuery)
              $(clicked).closest('td').find('span input').css('visibility', (on ? 'visible' : 'hidden'));
            }
          </script>

          <label>
            <input onchange="#{choice_off}" name="advisory[#{choice_name}]" type="radio" value="off"
              #{"disabled='disabled'" if disabled}
              #{"checked='checked'" if !present_now}
            />
            #{opts[:choice_off_label]}
          </label> &nbsp;

          <label>
            <input onchange="#{choice_on}" name="advisory[#{choice_name}]" type="radio" value="on"
              #{"disabled='disabled'" if disabled}
              #{"checked='checked'" if present_now}
            />
            #{opts[:choice_on_label]}:
          </label> &nbsp;

          <span style="#{'visibility:hidden' if !present_now}">
            #{text_field(object, method, opts)}
          </span>

          #{explanation}
        </td>
      </tr>
    |.html_safe
  end

  def row_label(label_text, object_name=nil, method_name=nil, options = {})
    label_text = label(object_name, method_name, label_text) if object_name && method_name

    if options[:anchor]
      anchor = options.delete(:anchor)
      label_text = %{<a name="#{anchor}"></a>#{label_text}}
    end

    if options[:label_help]
      label_help = block_render('shared/help_popover') do
        options[:label_help]
      end
    end

    %{<td class="header-label" width = "150">#{label_text}: &nbsp;#{label_help}</td>}.html_safe
  end

  def format_comment(text)
    text.gsub!(/&#010;/,"\n")

    # Some comments have double blank lines, so try stripping
    # them down to a single blank line so it looks nicer.
    text.gsub!(/\n\n+/, "\n\n")
    text.strip!

    #
    # This will escape ampersands in links.
    # (See auto_link_test.rb)
    #
    # Warning, a side effect of calling html_escape is that text becomes
    # an ActiveSupport::SafeBuffer. This causes some major weirdness
    # in errata_convert_links. See Bz 767378.
    #
    text = ERB::Util::html_escape(text)


    if text =~ /__div_bug_states_separator/
      text = text.gsub('__div_bug_states_separator', "<div class='bug_states_separator'>")
      if text =~ /__end_div/
        text = text.gsub('__end_div', "</div>")
      else
        # Some bug comments, such as kernel, may exceed the 4k limit, and strip off the _end_div
        # tag on creation. Ensure div is always closed.
        text += "</div>"
      end
    end
    # :sanitize=>false here prevents the already escaped ampersands from
    # being escaped again by auto_link (see auto_link_test.rb)
    auto_link(errata_convert_links(text), :sanitize=>false).html_safe
  end

  def errata_convert_links(text)
    # The regex fails in weird ways if text is an ActiveSupport::SafeBuffer
    # instead of a plain old string. I don't know why.
    # This is a workaround/hack to deal with that. See Bz 767378.
    # Make sure text is a plain old string:
    text = String.new(text)

    # convert all errata references
    text = text.gsub(/((RH[BES]A-)?(20[[:digit:]]{2}:[[:digit:]]{4,5})(-[[:digit:]]{2}(?!\d))?( comment #?([[:digit:]]{1,3}))?)/) do |s|
      link_errata = Errata.find(:first, :conditions => ["fulladvisory like ? or old_advisory like ?", "%#{$3}%", "%#{$3}%"]);
      if(link_errata)
        synopsis = ERB::Util::html_escape(link_errata.synopsis)
        s = "<a href=\"#{link_errata.id.to_s}" + ( $6 ? "#c#{$6}" : "" ) + "\" title=\"#{synopsis}\">#{$1}</a>"
      else
        s = $1
      end
    end

    @bugs_by_id ||= @errata.bugs.each_with_object({}) {|bug,h| h[bug.id] = bug}
    # convert all bz references
    text = text.gsub(/((bug|bz) ?#?([[:digit:]]{4,8})( comment #?([[:digit:]]{1,3}))?)/i) do |s|
      id = $3.to_i
      bug = @bugs_by_id[id] || Bug.find_by_id(id)
      if bug
        title = ERB::Util::html_escape("#{bug.bug_status} - #{bug.short_desc}")
        link = "<a href=\"#{bug.url}" +
          ( $5? "#c#{$5}" : "" ) +
          "\" title=\"#{title}\">#{$1}</a>"
        link = "<s>#{link}</s>" if bug.bug_status == "CLOSED"
        s = link
      else
        # FIXME: why should this ever happen?
        s = "<a href=\"#{Bug.base_url}/show_bug.cgi?id=#{$3}" + ( $5 ? "#c#{$5}" : "" ) + "\">#{$1}</a>"
      end
    end

    # convert JIRA references
    text = text.gsub(/(Jira\s+(?:(?:issue|task|item)\s+)?)([A-Z][A-Z0-9_]+-[0-9]+)/i) do |s|
      jira_issue = JiraIssue.find_by_key($2)
      if jira_issue
        link = "<a href=\"#{jira_issue.url}\">#{$2}</a>"
        link = "<s>#{link}</s>" if jira_issue.status == Settings.jira_closed_status
        s = "#{$1}#{link}"
      else
        s = "#{$1}#{$2}"
      end
    end
    text.html_safe
  end

  #
  # Nice embargo date display
  #
  def embargo_date_display(errata, opts={})
    if errata.embargo_date.present?
      if errata.not_embargoed?
        "<div class='compact'>Embargo<br/>#{errata.embargo_date.to_s(:Y_mmm_d)}</div>".html_safe
      else
        ("<div class='compact red bold'>" +
          (opts[:skip_label] ? "" : "<small>EMBARGOED!</small><br/>") +
          "#{errata.embargo_date.to_s(:Y_mmm_d)} #{"<br/>" unless opts[:no_br]}" +
          "<small>(#{time_ago_future_or_past(errata.embargo_date)})</small>" +
        "</div>").html_safe
      end
    else
      "<div class='small superlight'>#{opts[:none_text]||'-'}</div>".html_safe
    end
  end

  #
  # Display impact
  # TODO, combine these into one method.
  #
  def impact_display(errata)
    errata.short_impact.present? ?
      "<span title='#{errata.security_impact}' class='impact_indicator impact_#{errata.short_impact.downcase}'>[#{errata.short_impact.upcase}]</span>".html_safe :
      ""
  end

  def long_impact_display(errata)
    errata.short_impact.present? ?
      "<span title='#{errata.security_impact}' class='impact_indicator impact_#{errata.short_impact.downcase}'>#{errata.security_impact}</span>".html_safe :
      "-"
  end

  #
  # Nice publish date and explanation
  #
  def publish_date_and_explanation(errata)
    bold = errata.publish_date_explanation == 'custom'
    # This is very ugly, sorry! (fixme)
    html = ''
    html << '<div class="compact">'
    html << '<b>' if bold
    html << [h(errata.publish_date_for_display),"<small style='color:#888'>(#{errata.publish_date_explanation})</small>"].compact.join('<br/>')
    html << '</b>' if bold
    html << '<br/>'
    html << "<small>#{time_ago_future_or_past(errata.publish_or_ship_date_if_available)}</small>" if errata.publish_or_ship_date_if_available
    html << '</div>'
    html.html_safe
  end

  def batch_description(errata)
    return none_text unless errata.batch
    html = '<div class="compact">'
    html << link_to(errata.batch.name, errata.batch)
    html << '<br>'
    if !errata.batch.is_active?
      html << content_tag(:span, '(inactive)', :class=>'tiny bold')
    elsif errata.is_batch_blocker?
      html << content_tag(:span, 'BLOCKER', :class=>'tiny bold')
    end
    html << '</div>'
    html.html_safe
  end

  # wrappper for bugzilla bugs
  def bug_status_stats_text(errata)
    params = {
      :issues => errata.bugs,
      :field_name => :bug_status,
      :always_shown => %w[VERIFIED ON_QA],
    }
    issue_status_stats_text(params)
  end

  # wrappper for JIRA issues
  def jira_issue_status_stats_text(errata)
    always_shown = Settings.jira_always_shown_states || ['QA In Progress', 'Verified']
    params = {
      :issues => errata.jira_issues,
      :field_name => :status,
      :always_shown => always_shown,
    }
    issue_status_stats_text(params)
  end

  #
  # Small text display of bugs counts and percentages grouped by status.
  # To keep if from being too long we group statuses as 'Other' if there
  # are too many of them. See Bug 820110.
  #
  def issue_status_stats_text(params={})

    [:issues, :field_name, :always_shown].each do |key|
       raise ArgumentError, "missing #{key}" if params[key].nil?
    end

    issues = params[:issues]
    field_name = params[:field_name]
    always_shown = params[:always_shown]

    total_issues = issues.count

    # Group the issues according to their status.
    # (grouped_issues is now a hash of issue lists with issue statuses as the keys).
    grouped_issues = issues.group_by(&field_name)

    # Sort with the biggest number first.
    # (Now grouped_issues is an ordered array of key/value pairs)
    grouped_issues = grouped_issues.sort_by{ |status, list| -list.count }

    # Want to show the top three statuses by issue count, then tally up the rest as 'Other'.
    grouped_issue_counts = Hash.new{0}
    shown_count, other_count, replace_other_label = 0, 0, nil
    grouped_issues.each do |status, list|
      if shown_count < 3 || always_shown.include?(status)
        # Will be shown separately
        grouped_issue_counts[status] = list.count
        shown_count += 1
      else
        # Will be lumped in with 'Other'
        grouped_issue_counts['Other'] += list.count
        other_count += 1
        replace_other_label = status
      end
    end

    # Hack. If there's only one type in 'Other' we might as well show what it really is.
    if other_count == 1
      grouped_issue_counts[replace_other_label] = grouped_issue_counts['Other']
      grouped_issue_counts.delete('Other')
    end

    # Now we have to sort again since grouped_issue_counts is a hash.
    # Let's make 'Other' appear last always.
    grouped_issue_counts = grouped_issue_counts.sort_by { |status, count| status == 'Other' ? 0 : -count }

    # Prepare the text using grouped_issue_counts.
    # Add an extra space to make it a little more readable.
    # Looks something like this: NEW: 4 (33%),  ASSIGNED: 4 (33%),  ON_QA: 2 (17%),  Other: 2 (17%)
    (grouped_issue_counts.map do |status, count|
      "#{status}: #{count} (#{number_to_percentage(100.0 * count / total_issues, :precision=>0)})"
    end).join(',&nbsp; ').html_safe
  end

  private
  def errata_text_row(label, options)
    row_id = options.delete(:row_id)
    row_id ||= label.downcase.gsub(' ', '_').gsub('\'','')
    style = ''
    if options[:style]
      style = "style=\"#{options[:style]}\""
      options.delete(:style)
    end
    "<tr id='#{row_id}' #{style}>#{row_label(label,nil,nil,options)}".html_safe
  end

  def time_ago_in_words_no_about(time, show_secs)
    # Maybe there is a better way to do this..
    time_ago_in_words(time, show_secs).gsub(/about /,'')
  end

  def time_ago_future_or_past(time, show_in_prefix=false)
    time_now = Time.now
    if time < time_now
      "#{time_ago_in_words_no_about(time, true)} ago"
    else
      "#{'In ' if show_in_prefix}#{time_ago_in_words_no_about(time, true)}"
    end
  end

  def mailto_link_or_unassigned(errata, assigned_to_method, is_unassigned_method)
    if errata.send(is_unassigned_method)
      content_tag(:i, 'unassigned', :class=>'small superlight', :title=>errata.send(assigned_to_method).short_to_s)
    else
      longer_mailto_link(errata.send(assigned_to_method))
    end
  end

  #
  # These might be better in a separate helper module.
  # They are used in details and view.
  # They get rendered by table_rows_helper.
  #
  def errata_details_tabular(details_mode,errata)
    private_method_name = "errata_details_table_#{details_mode}"
    raise "Unknown details table #{details_mode}" unless ErrataHelper.private_method_defined?(private_method_name)
    method(private_method_name).call(errata)
  end

  def status_and_deleted_and_closed_display(errata)
    return ("<big>#{state_display(errata)}</big>" +
    "#{ '<span class="light bold"> Closed</span>' if errata.closed? }" +
    # It might be that everything dropped is also deleted and vice versa so this is possibly superflous...
    "#{' <span class="red bold"> Deleted!</span>' if errata.is_valid != 1}").html_safe
  end

  #
  # Renders advisory indicators for the advisory list to give the user
  # information of special advisory attributes. If multiple come to
  # pass, the indicators are delimited with a "/" instead of a small
  # white space by default.
  #
  def render_indicators(errata)
    indicators = []
    [
      [:text_only?, 'TEXT ONLY', ''],
    ].each do |attr, label, title|
      result = errata.send(attr)
      next unless result
      indicators << content_tag(:span, label, :class => 'tiny bold', :title => title)
    end
    indicators << supports_multi_product_label_title(errata, 'tiny bold')
    indicators.join("/").html_safe
  end

  private

  def errata_details_table_brief_summary(errata)
    [
      [
        'Product',      errata.product.short_name,
        'Package Owner',longer_mailto_link(errata.package_owner),
        'QA Owner',     mailto_link_or_unassigned(errata, :assigned_to, :unassigned?),
        'Status',       status_and_deleted_and_closed_display(errata),
      ],
      [
        'Release',      errata.release.name,
        'Release date', safe_join( [ errata.publish_date_for_display,
                          content_tag(:span, "(#{errata.publish_date_explanation})", :class=>'small light')
                        ], ' '),
        'Embargo',      embargo_date_display(errata, :none_text=>'None', :skip_label=>true, :no_br=>true),
        'QE group',     errata.quality_responsibility.name,
      ],
      [
        'Impact',       impact_display(errata),
        'Topic',        {:colspan=>3,:small=>true,:content=>content_popover_helper(errata.content.topic, 'Topic', {:action=>:details,:id=>errata})},
        {:colspan=>4,:tiny=>true,:content=>"(See #{link_to('details tab',{:action=>'details',:id=>errata})} for more info)".html_safe},
      ]
    ]
    end

  def errata_details_table_detail_main(errata)
    [
      [
        'Product',            link_to(errata.product.long_name, {:controller=>:products, :action=>:show, :id=>errata.product.short_name}),
        'Package Owner',      longer_mailto_link(errata.package_owner),
        'Creation Date',      nice_date(errata.created_at),
      ],
      [
        'Release',            link_to(errata.release.name,      { :controller=>:release,  :action=>:show, :id=>errata.release }),
        'QA Owner',           mailto_link_or_unassigned(errata, :assigned_to, :unassigned?),
        'Responsible Group',  errata.package_owner.try(:organization).try(:name) || '-',
      ],
      [
        'Type',               [
                              content_tag(:span, "#{errata.fulltype_shorter} (#{errata.errata_type})",
                                :class => "show_type show_type_#{errata.errata_type}"),
                              (content_tag(:span, ' TEXT ONLY', :class=>'tiny bold') if errata.text_only?)
                            ].compact.join(' ').html_safe,
        'Package Owner Manager',longer_mailto_link(errata.manager),
        'QE Group',           errata.quality_responsibility.name,
      ] ,
      [
        'Security Impact',    long_impact_display(errata),
        'Reporter',           longer_mailto_link(errata.reporter),
        'Status',             status_and_deleted_and_closed_display(errata),
      ],
      [
        'Multi-product',      supports_multi_product_label_title(errata),
        'Docs Reviewer',      mailto_link_or_unassigned(errata, :doc_reviewer, :docs_unassigned?),
        'Docs Status',        errata.docs_status_text_short,
      ],
      ['CPE Text', {:colspan => 5, :content => render(:partial => "errata/cpe_list")}]
    ]
  end

  def reboot_suggested_value(errata)
    (suggested, why) = errata.reboot_suggested_with_reasons
    return 'No' unless suggested

    content_popover_helper(
      safe_join(why, "<br>".html_safe),
      'Reboot is suggested because:',
      '#',
      :manual_text => 'Yes',
      :class => ['help-cursor'])
  end

  def errata_details_table_detail_qe(errata)
    blocking_text   = safe_join(errata.blocking_errata.map{ |e| errata_link(e) }, ', ')
    blocking_text   = '-' unless blocking_text.present?

    dependent_text = safe_join(errata.dependent_errata.map{ |e| errata_link(e) }, ', ')
    dependent_text = '-' unless dependent_text.present?

    cc_list_text = safe_join(errata.cc_emails_short, ', ')
    cc_list_text = '-' unless cc_list_text.present?
    # Enclose in a span so we can update it dynamically. (See ErrataController#add_comment).
    cc_list_span = content_tag(:span, cc_list_text, :id=>'cc_list_text')

    [
      [ 'Synopsis',   {:colspan=>3, :content=>errata.synopsis, :small=>true, :bold=>true } ],
      [ 'Cc List',    {:colspan=>3, :content=>cc_list_span,    :tiny=>true } ],
      [ 'Depends On', {:colspan=>3, :content=>blocking_text,   :tiny=>true } ],
      [ 'Blocks',     {:colspan=>3, :content=>dependent_text,  :tiny=>true } ],
      [
        'Bug Count',   n_thing_or_things(errata.bugs, 'bug'),
        'Build Count', n_thing_or_things(errata.brew_builds, 'build'),
      ],
      [ 'Bug Statuses', {:colspan=>3, :content=>bug_status_stats_text(errata), :small=>true } ],
      [
        'Respin Count',     n_thing_or_things(errata.respin_count, 'respin'),
        'Reboot Suggested', reboot_suggested_value(errata),
      ],
      ( [
        'Container',      link_to(n_thing_or_things(errata.container_errata.count, 'content advisory'),
                                  url_for(:action => :container, :id => errata)),
        'Container Bugs', n_thing_or_things(errata.container_errata.map(&:bugs).flatten.uniq.count, 'bug')
      ] if errata.is_container_advisory? && errata.has_container_errata? ),
    ]
  end

  def errata_details_table_detail_date(errata)
    [
      ['Release Date',   "#{errata.publish_date_for_display} <span class='small'>(#{errata.publish_date_explanation})</span>".html_safe],
      ['Embargo Date',   embargo_date_display(errata,:skip_label=>true, :no_br=>true)],
      ['Embargoed Now?', (errata.is_embargoed? ? '<span class="red bold">YES</span>' : '<span class="green">No</span>').html_safe],
      ['Issue Date',     nice_date(errata.issue_date)],
      ['Update Date',    nice_date(errata.update_date)],
      ['Batch',          batch_description(errata) ],
    ]
  end

  def errata_details_table_content(errata)
    # (Abusing the divider rows here a bit...)
    [
      [ :divider, 2 ],
      ['Topic',                render('wrapped_unwrapped_text', :text=>errata.content.topic) ],
      ["Bugs (#{errata.bugs.count})", {:content=>render("errata/sections/bugs_content")} ],
      ["#{JiraIssue.readable_name} (#{errata.jira_issues.count})", {:content=>render("errata/sections/jira_issues_content")} ],
      [ :divider, 2 ],
      ['Problem Description',  render('wrapped_unwrapped_text', :text=>errata.content.description) ],
      [ :divider, 2 ],
      ['Solution',             render('wrapped_unwrapped_text', :text=>errata.content.solution) ],
      [ :divider, 2 ],
      ['Arches & Versions',     br_separated(errata.relarchlist)],
      [ :divider, 2 ],
      ['References',            auto_link(h(errata.content.reference).gsub(/\n/,'<br/>'),:sanitize=>false).html_safe], # See auto_link_test.rb
      ( ['CVE Names',           errata.cve_list.map { |c| cve_link(c) }.join(', ').html_safe ] if errata.is_security_related? ),
      ( ['Container CVEs',      errata.container_cves.map { |c| cve_link(c) }.join(', ').html_safe ] if errata.is_container_advisory? && errata.has_container_errata? ),
      ['Keywords',              errata.content.keywords],
      ['Cross References',     content_tag(:span, errata.content.crossref, :class => 'tiny')],
      [ :divider, 2 ],
      ( ['Text Only CPE',       {:pre=>true,:content=>errata.content.text_only_cpe}] if errata.can_have_text_only_cpe? ),
      ( [ :divider, 2 ] if errata.can_have_text_only_cpe? ),
      ( ['Product Version Text', {:pre=>true,:content=>errata.content.product_version_text.try(:gsub, ',', "\n")}] if errata.can_have_product_version_text? ),
      ( [ :divider, 2 ] if errata.can_have_product_version_text? )
    ].compact
  end

  def errata_details_table_howtest(errata)
    [
     [ :divider, 2 ],
     ["Notes<br/><span class='tiny superlight'>(was 'How to Test')</span>".html_safe,
      {:pre => true,
        :content => h(errata.content.how_to_test)}
     ],
    ]
  end

  def security_impact_select(errata, field_name, selected = nil)
    is_secalert = User.current_user.in_role?('secalert')
    is_persisted_rhsa = errata && errata.is_security?

    if is_persisted_rhsa
      # already have RHSA -> retain the current impact
      selected = errata.security_impact
    elsif !is_secalert
      # unprivileged user, no impact currently set -> preselect "Low"
      selected = 'Low'
    end
    # privileged user, no impact currently set -> no value preselected

    out = [select_tag(field_name, options_for_select(SecurityErrata::IMPACTS, selected), :disabled => !is_secalert)]
    if !is_secalert
      out << (<<-"eos")
        <br />
        <span class="light small">
          Because you do not have the secalert role, you may
          #{is_persisted_rhsa ? "not modify the security impact" : "only set an impact of 'Low'"}.
        </span>
eos
      out << hidden_field_tag(field_name, selected)
    end

    out.join.html_safe
  end

  def build_list_headers_for_mappings(mappings)
    have_nonrpm = mappings.any?{|m| m.brew_archive_type.present?}

    [
      mappings.first.release_version.display_name,
      'Build',
      ('File Types' if have_nonrpm),
      'Signed?',
    ].compact
  end

  def link_to_release_version(rv, options={})
    url = rv.is_pdc? ? rv.view_url : rv
    # The link goes to PDC so let's default to opening in a new tab
    options = options.reverse_merge(target: '_blank') if rv.is_pdc?
    link_to rv.short_name, url, options
  end

  def build_list_func_for_mappings(mappings)
    have_nonrpm = mappings.any?{|m| m.brew_archive_type.present?}
    lambda do |rows|
      # mappings have been grouped by product version and build
      rv = rows.first.release_version
      build = rows.first.brew_build
      file_types = safe_join(rows.map{|m|
        m.brew_archive_type.present? ? m.brew_archive_type.name : 'RPM'
      }.sort, ', ')

      [
        link_to_release_version(rv, :target => '_blank'),
        brew_link(build, :target=>'_blank'),
        (file_types if have_nonrpm),
        yes_no_icon(build.signed_rpms_written?),
      ].compact
    end
  end

  #
  # Use this key for caching non-current state indexes (comment groups) in
  # the summary tab.
  #
  # See app/views/errata/sections/_state_group_list.erb
  #
  # It's not good for current state indexes since they can get new comments.
  #
  # newest_first is a boolean that specifies the comment order
  #
  def non_current_state_index_cache_key(state_index, newest_first)
    "state_index/#{state_index.id}/#{newest_first}"
  end

  #
  # Use this key for caching comments on the summary tab.
  #
  # See app/views/errata/sections/_state_group.erb
  #
  def comment_cache_key(comment)
    "comment/#{comment.id}"
  end

  #
  # Error messages to display at top of advisory create/edit form.
  #
  # This is different from the default behavior because certain errors are
  # directly displayed next to form inputs and can be omitted from the error
  # section above the form.
  def advisory_form_error_messages(source = nil)
    source ||= @advisory

    object          = OpenStruct.new
    object.errors   = AdvisoryFormErrorsWithFilter.new(source.errors)
    object.to_model = object

    error_messages_for(
      object,
      :object_name => 'advisory',
      :message => 'Please review the highlighted fields below.')
  end

  #
  # Used by advisory container content tab, to consolidate
  # content advisories that are in multiple repos (instead
  # of displaying duplicates).
  #
  def build_container_content(build, content, opts={})
    container_repos = content.try(:container_repos) || []
    if opts[:consolidate] && container_repos.length > 1
      # errata that are common to all of the container_repos
      common_errata = container_repos.map(&:errata).reduce(:&)
      # throwaway copy of container repos without common_errata
      container_repos = container_repos.map do |r|
        ContainerRepo.new(:errata => r.errata - common_errata, :name => r.name, :cdn_repo_id => r.cdn_repo, :tags => r.tags, :comparison => r.read_attribute(:comparison))
      end
    end
    return container_repos, common_errata
  end

  def supports_multi_product_label_title(errata, css='')
    return '' if errata.supports_multiple_product_destinations.nil?
    label, title = errata.supports_multiple_product_destinations? ?
                     ['MULTI-ON', 'Supports shipping packages to multiple products'] :
                     ['MULTI-OFF', "'Multiple Products' feature has been disabled"]
    content_tag(:span, label, :class => css, :title => title)
  end

  #
  # Returns either 'CDN' or 'RHN' as appropriate
  #
  def dist_indicator_text(dist)
    case dist
    when PDC::V1::ContentDeliveryRepo
      # dist.service should be either 'pulp' or 'rhn'
      dist.service == 'pulp' ? 'CDN' : dist.service.upcase
    else
      # Use class method for Channel & CdnRepo
      dist.class.short_display_name
    end
  end

  def link_to_manual_create(is_pdc:)
    action = is_pdc ? :new_pdc_errata : :new
    link_to 'manual create', controller: :errata, action: action
  end
end
