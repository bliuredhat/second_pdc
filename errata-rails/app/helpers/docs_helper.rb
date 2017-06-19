module DocsHelper
  def change_reviewer_link(errata_id, reviewer_id)
    html_options = {:id => "review_#{errata_id}",
      :href => '#',
      :class => 'btn btn-mini tiny',
      :style => 'padding:0 5px;color:#333;',
      'data-errata-id' => errata_id,
      'data-reviewer-id' => reviewer_id}
    content_tag(:a, 'Edit', html_options)
  end
  #
  # Used in app/views/docs/_doc_queue.rhtml for display and sorting the release
  # date column in the Docs Queue.
  #
  # See Silas's specs at https://bugzilla.redhat.com/show_bug.cgi?id=731201
  #
  # Going to return an array with two values. The first is the value to display and
  # the second is the value to use for sorting. If there is no release date then
  # show ASYNC or EUS if applicable, otherwise show blank.
  #
  # (Not quite clear on FastTrack, will ask for clarification..)
  #
  # The 10, 20, 30, 40, affects the sort order when sorting by this column alphabetically
  # using tablesort.js
  #
  def release_date_display_helper(errata)
    release_date = errata.publish_date
    if release_date.present?
      # These sort third, after ASYNC and EUS, hence 30, (and then by the release date)
      # The date format is "Aug 9" but if that is ambiguous then show the year as well
      [release_date.to_s(:Y_mmm_d), "30-#{release_date.to_f.to_i}"]

    elsif errata.release.is_a?(Async) || errata.release.is_a?(FastTrack)
      # These sort first, hence 10
      ['ASAP',"10"]

    elsif errata.release.is_a? Zstream
      # These sort second, hence 20
      ['EUS',"20"]

    else
      # These sort last, hence 40
      ['',"40"]

    end
  end

  def reverse_alpha_sort_index(state)
    "%012i" % (100000000 - State.sort_order[state])
  end

  #
  # Display color coded indicator to show status of the Doc Text for a bug.
  # Used in doc_text_info.html.erb.
  # Sort so that items requiring attention come first.
  #
  def requires_doc_text_flag_display(bug)
    text, css_suffix, title, flag_sort = case bug.flags_list.flag_state('requires_doc_text')
    when BzFlag::PROPOSED; ['?',           'reqd',     'requires_doc_text? (PROPOSED)',  '10'] # Doc text required and not complete
    when nil;              [raw('&nbsp;'), 'unknown',  'requires_doc_text flag not set', '20'] # Flag not set (but assume doc text required)
    when BzFlag::ACKED;    ['+',           'done',     'requires_doc_text+ (ACKED)',     '30'] # Doc text required and complete
    when BzFlag::NACKED;   ["-",           'not-reqd', 'requires_doc_text- (NACKED)',    '40'] # Doc text not required
    end
    # secondary sort by package name, then priority
    sort_key = "#{flag_sort}-#{bug.package.name_sort_with_docs_last.downcase}-#{bug.priority_order}"
    tablesort_helper(content_tag(:span, text, :class=>"docs-flag docs-flag-#{css_suffix}", :title=>title), sort_key)
  end

end
