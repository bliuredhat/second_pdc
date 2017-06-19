#
# Helper methods for use with the bz_table shared partial.
# See app/views/shared/_bz_table.html.erb
#
# TODO:
# - Some of the row_for_* and headings_for_* methods are used in just one
#   place, so they might as well be inlined in the template
# - This stuff is a bit of a mess, could use some refactoring/rewriting.
#
module BzTableHelper

  #---------------------------------------------------------------
  #
  # For numeric sorting or for sorting by a field other
  # than the raw contents of the table cell in jquery.tablesort.js
  #
  # The numeric vs alpha sort is now controlled by the column heading.
  # See tablesort_heading_custom_sort and tablesort_heading_custom_sort_numeric.
  #

  def tablesort_helper(display_value, sort_value, opts={})
    { :content => display_value, :options => opts.merge({ 'data-sort' => sort_value }) }
  end

  def sortable_time_ago_in_words(timestamp)
    # This is only to prevent error for time_ago_in_words
    # nil shouldn't be happen for the date column
    if timestamp.nil?
      tablesort_helper("Unknown", 'Unknown')
    else
      tablesort_helper(time_ago_future_or_past(timestamp, true), timestamp.to_i, :title => timestamp.utc.to_s)
    end
  end

  def sortable_yes_no_icon(condition)
    tablesort_helper(yes_no_icon(condition), condition ? 1 : 0)
  end

  #
  # Special sorting by fulladvisory RHSA > RHBA > RHEA
  #
  def special_fulladvisory_sort_helper(fulladvisory)
    case fulladvisory
    when /^RHSA/
      "1000_#{fulladvisory}"
    when /^RHBA/
      "2000_#{fulladvisory}"
    when /^RHEA/
      "3000_#{fulladvisory}"
    else
      # should never get here?
      "4000_#{fulladvisory}"
    end
  end

  #
  # When you want to sort by something other than the raw cell text
  # For tablesort_helper to work you need to use this in the corresponding table heading.
  #
  def tablesort_heading_custom_sort(heading_text, sort_type='Text')
    { :content => heading_text, :options => { :class => "sortable sorter-cellData#{sort_type}Sort" } }
  end

  #
  # When you want to sort numerically by something other than the raw cell text
  # For tablesort_helper to work you need to use this in the corresponding table heading.
  #
  def tablesort_heading_custom_sort_numeric(heading_text)
    tablesort_heading_custom_sort(heading_text, 'Number')
  end

  #
  # To disable sorting on a particular column.
  #
  def tablesort_heading_no_sort(heading_text, opts={})
    { :content => heading_text, :options => opts.merge({ :'data-sorter'=>'false' }) }
  end

  #---------------------------------------------------------------

  def embargo_date_content(errata)
    tablesort_helper(
      bold_red_if(errata.is_embargoed?, errata.embargo_date_for_display),
      errata.embargo_date.try(:to_i))
  end

  def release_date_content(errata, opts={})
    tablesort_helper(
      opts[:long] ? errata.publish_date_and_explanation : errata.publish_date_for_display,
      errata.publish_date_sort_by)
  end

  #
  #---------------------------------------------------------------
  #
  # For use when passing data into bz_table shared partial
  #

  def headings_for_filed_bug
    [
      tablesort_heading_custom_sort_numeric('Bug ID'),
      tablesort_heading_custom_sort_numeric('Priority'),
      tablesort_heading_custom_sort_numeric('Status'),
      'Advisory',
      'Description'
    ]
  end

  def row_for_filed_bug(filed_bug)
    bug = filed_bug.bug
    [
      tablesort_helper(bug_link(bug), bug.id),
      tablesort_helper(bug.priority, bug.priority_order),
      tablesort_helper(bug.bug_status, bug.status_order),
      errata_link(filed_bug.errata),
      bug_metadata(bug),
    ]
  end

  def headings_for_errata_bug
    [
      tablesort_heading_custom_sort_numeric('Bug ID'),
      tablesort_heading_custom_sort_numeric('Priority'),
      tablesort_heading_custom_sort_numeric('Status'),
      'Verified',
      tablesort_heading_custom_sort_numeric('Last Updated'),
      'Description',
      'Private?',
    ]
  end

  def row_for_errata_bug(bug)
    r = [
      tablesort_helper(bug_link(bug), bug.id),
      tablesort_helper(bug.priority, bug.priority_order),
      tablesort_helper(bug.bug_status, bug.status_order),
      bug.verified.blank? ? '&nbsp; -'.html_safe : bug.verified,
      sortable_time_ago_in_words(bug.last_updated),
    ]
    r << bug_metadata(bug)
    r << (bug.is_private? ? '<span class="tiny red bold">PRIVATE</span>' : '<span class="tiny superlight">public</span>').html_safe
    if bug.is_private?
      { :content => r, :options => { :extra_class => "bz_private" } }
    else
      r
    end
  end

  def headings_for_errata_list
    [
      'Advisory',
      'Product',
      'Release',
      'Synopsis',
      tablesort_heading_custom_sort_numeric('Embargo'),
      tablesort_heading_custom_sort('Release'),
      'QE Owner',
      'QE Group',
      'Status',
      tablesort_heading_custom_sort_numeric('Status Time'),
    ]
  end

  def row_for_errata_list(errata)
    link = image_tag("#{errata.class}.gif")
    link += errata_link(errata)

    embargo_date = embargo_date_content(errata)
    publish_date = release_date_content(errata, :long => true)

    row = [link, errata.product.short_name, errata.release.name, errata.synopsis, embargo_date, publish_date]
    row << errata.assigned_to.login_name
    row << errata.quality_responsibility.name
    row << errata.status
    row << sortable_time_ago_in_words(errata.status_updated_at)
    row
  end

  def headings_for_my_errata
    [
      'Advisory',
      'Product',
      'Release',
      'Synopsis',
      tablesort_heading_custom_sort_numeric('Embargo'),
      tablesort_heading_custom_sort('Release'),
      'QE Group',
      'Status',
      tablesort_heading_custom_sort_numeric('Status Time'),
    ]
  end

  def row_for_my_errata(r)
    # Note: `user` is not actually used here any more
    errata, attention_required, user = r

    link = image_tag("#{errata.class}.gif")
    link += errata_link(errata)

    embargo_date = embargo_date_content(errata)
    publish_date = release_date_content(errata, :long => true)

    row = [link, errata.product.short_name, errata.release.name, errata.synopsis, embargo_date, publish_date]
    row << errata.quality_responsibility.name
    row << errata.status
    row << sortable_time_ago_in_words(errata.status_updated_at)

    if attention_required
      { :content => row, :options => { :extra_class => "errata_row bz_warning" } }
    else
      { :content => row, :options => { :extra_class => "errata_row" } }
    end
  end

  def headings_for_errata_for_release
    [
      'Advisory',
      'Synopsis',
      'QE Owner',
      'Dev Group',
      'Status',
      tablesort_heading_custom_sort_numeric('Status Time'),
      tablesort_heading_custom_sort_numeric('Bugs Completed'),
    ]
  end

  def row_for_errata_for_release(errata)
    link = image_tag("#{errata.class}.gif")
    link += errata_link(errata)
    if errata.unassigned?
      assigned = "UNASSIGNED"
    else
      assigned = { :content => errata.assigned_to.login_name, :options => {
        :title => errata.assigned_to.realname } }
    end
    if errata.verified_bugs.length == errata.bugs.length
      bugs = "All #{errata.bugs.length}"
    else
      bugs = "#{errata.verified_bugs.length} out of #{errata.bugs.length}"
    end
    row = [link, errata.synopsis, assigned, errata.severity, errata.status]
    row << sortable_time_ago_in_words(errata.status_updated_at)
    row << tablesort_helper(errata.bugs.length, errata.bugs.length)
    row
  end

  def headings_for_errata_list2
    [
      'Advisory',
      'Product',
      'Release',
      'Reporter',
      tablesort_heading_custom_sort_numeric('Embargo'),
      'Impact',
      'Synopsis',
      tablesort_heading_no_sort('D', :title => 'Docs complete'  ),
      tablesort_heading_no_sort('Q', :title => 'QA complete'    ),
      tablesort_heading_no_sort('H', :title => 'RHNQA pushed'   ),
      tablesort_heading_no_sort('F', :title => 'Files pushed'   ),
      tablesort_heading_no_sort('N', :title => 'RHN Live pushed'),
      tablesort_heading_no_sort('M', :title => 'Errata mailed'  ),
      tablesort_heading_no_sort('C', :title => 'Closed'         ),
    ]
  end

  def row_for_errata_list2(errata)
    link = link_to(errata.advisory_name, {:id => errata, :controller => :errata, :action => :view}, :class=>'advisory_link')
    tr_options = errata.is_critical? ? { :class => "bz_warning" } : {}

    row = [
      link,
      errata.product.short_name,
      errata.release.name,
      errata.reporter.short_name,
      (tablesort_helper(time_ago_future_or_past(errata.embargo_date), errata.embargo_date.to_i,
        :title => errata.embargo_date.to_s, :class=>(errata.is_embargoed? ? 'bold red' : 'light')) if errata.embargo_date.present?),
      errata.short_impact, errata.synopsis,
      yes_no_icon(errata.doc_complete?),
      yes_no_icon(errata.qa_complete?),
      yes_no_icon(errata.rhnqa?),
      yes_no_icon(errata.pushed?),
      yes_no_icon(errata.published?),
      yes_no_icon(errata.mailed?),
      yes_no_icon(errata.closed?)
    ]

    { :content => row, :options => tr_options }
  end

  def headings_for_errata_for_qe_group
    [
      'Advisory',
      'Synopsis',
      'QE Owner',
      tablesort_heading_custom_sort_numeric('Embargo'),
      tablesort_heading_custom_sort_numeric('Release'),
      'Status',
    ]
  end

  def row_for_errata_for_qe_group(errata)
    row = [
      link_to(errata.advisory_name, :controller => :errata, :action => :show, :id => errata),
      errata.synopsis
    ]
    if(errata.unassigned?)
      row << link_to('Take Ownership', {:action => :assign_errata_to_me, :id => errata}, :method => :post)
    else
      row <<  "#{errata.assigned_to}"
    end
    row << embargo_date_content(errata)
    row << release_date_content(errata)
    row << state_display(errata)
    row
  end

  def compose_row_function(row_fns, opts = {})
    rows_per_item = row_fns.length
    even_odd = [['bz_even']*rows_per_item, ['bz_odd']*rows_per_item].flatten.cycle

    i = 0
    row_fns = row_fns.map do |fn|
      was_sym = fn.kind_of?(Symbol)
      fn = fn.to_proc
      style = [opts[:style]].compact
      unless i == 0
        style << 'border-top:none!important'
      end
      unless i == rows_per_item-1
        style << 'border-bottom:none!important'
      end

      i += 1

      lambda do |x|
        row_opts = opts.dup.merge(:class => even_odd.next, :style => style.join(';'))
        args = [x, row_opts]
        args.unshift(self) if was_sym
        fn.call(*args)
      end
    end.cycle

    lambda{|x| row_fns.next.call(x)}
  end

end
