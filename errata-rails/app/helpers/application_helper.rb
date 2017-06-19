# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include BzTableHelper
  include JiraIssueTableHelper
  include ActionView::Helpers::OutputSafetyHelper
  include CacheIfHelper

  def back_to_errata(errata)
    link_to("Back to #{errata.shortadvisory}",
            :controller => :errata,
            :action => :view,
            :id => errata)
  end

  def back_to_info(errata)
    back_to_errata(errata)
  end

  def br_separated(arry)
    arry.collect {|a| ERB::Util.h(a)}.join("<br/>\n").html_safe
  end

  def push_info_link(package, variant)
    push_info_link_helper(package.supported_push_types_by_variant(variant))
  end

  def push_info_link_pdc(release_version)
    push_info_link_helper(release_version.push_targets.map(&:name))
  end

  def push_info_link_helper(push_types)
    content = if push_types.any?
      content_tag(:ul) do
        push_types.map{|push_type| content_tag(:li, push_type)}.join
      end
    else
      content_tag(:span, content_tag(:i, "NONE"))
    end
    title = "This brew build is being set to push to:"
    content_popover_helper(content, title, '#push_targets', {:manual_text => "Push info", :click => true})
  end

  def brew_link(build, opts={})
    link_to(build.nvr, "#{Brew.base_url}/buildinfo?buildID=#{build.id}", opts)
  end

  def brew_file_link(file, opts={})
    suffix = file.kind_of?(BrewRpm) ? 'rpminfo?rpmID=' : 'archiveinfo?archiveID='
    brief = opts.delete(:brief)
    path = brief ? file.filename_with_subpath : file.file_path
    link_to(path, "#{Brew.base_url}/#{suffix}#{file.id_brew}", opts)
  end

  def brew_file_type_display(file, opts={})
    safe_join([
      content_tag('span', opts.merge(:title => file.file_type_description)) do
        file.file_type_display
      end,
      ("(#{file.arch.name})" if file.arch_id.present?),
    ], ' ')
  end

  def bug_link(bug, opts={})
    link_to(bug.id, bug.url, opts)
  end

  def jira_issue_link(jira_issue, opts={})
    link_to(jira_issue.key, jira_issue.url, opts)
  end

  def link_to_bug_list(link_text, bugs, opts={})
    link_to link_text, "#{Bug.base_url}/buglist.cgi?bug_id=#{idlist(bugs)}", opts
  end

  def link_to_jira_issue_list(link_text, jira_issues, opts={})
    jira_issue_list = jira_issues.collect{ |i| "'#{i.key}'"}.join(',')

    link_to link_text, "#{JiraIssue.base_url}/issues/?jql=#{url_encode("key in (#{jira_issue_list})")}".html_safe, opts
  end

  # See here for list of glyph-icons:
  # http://twitter.github.com/bootstrap/base-css.html#icons
  def icon_btn_text(text, glyph_icon, opts={})
    right_icon = opts[:right_icon]
    # glyph_icon kerning tweak.. :P
    padding = glyph_icon == 'plus' ? 0 : 2
    glyph_icon = 'ok'     if glyph_icon.is_a? TrueClass
    glyph_icon = 'remove' if glyph_icon.is_a? FalseClass
    %{#{text if right_icon}<i class="icon-#{glyph_icon}" style="opacity:#{opts[:opacity]||'0.4'};padding-#{right_icon ? 'left' : 'right'}:#{padding}px;"></i>#{text unless right_icon}}.html_safe
  end

  def icon_btn_text_right(text, glyph_icon, opts={})
    icon_btn_text(text, glyph_icon, :right_icon=>true)
  end

  def icon_btn_link(text, glyph_icon, link, opts={})
    link_to(icon_btn_text(text, glyph_icon), link, opts)
  end

  def is_active_icon(is_active)
    content_tag(
      :span,
      is_active ? icon_btn_text('active', :ok) : icon_btn_text('inactive', :'ban-circle'),
      :class=>'small light'
    )
  end

  def pdc_indicator
    content_tag(:span, "[PDC]", :class => 'pdc-indicator')
  end

  def pdc_indicator_if(condition)
    condition ? pdc_indicator : ""
  end

  def pdc_indicator_for(errata_or_release)
    pdc_indicator_if(errata_or_release.is_pdc?)
  end

  def make_filter_url(filter_params)
    { :controller => :errata, :action => :index }.
      merge(:errata_filter => {:filter_params => ErrataFilter::FILTER_DEFAULTS_NOT_DROPPED.merge(filter_params) })
  end

  def filter_url_for_product(product)
    make_filter_url(:product => [product.id])
  end

  def filter_url_for_batch(batch)
    make_filter_url(:batch => [batch.id], :sort_by_fields => [:batchblock])
  end

  def cve_link(cve)
    link_to cve, cve_url(cve)
  end

  def cve_url(cve)
    sprintf(Settings.cve_url, cve)
  end

  def it_link(id)
    link_to id, it_url(id)
  end

  def it_url(id)
    "https://enterprise.redhat.com/issue-tracker/?module=issues&action=view&tid=#{id}"
  end

  def sig_keys_link
    link_to sig_keys_url, sig_keys_url
  end

  def sig_keys_url
    Settings.sig_keys_url
  end

  def days_until_today(date)
    return '' unless date
    (Time.now.to_datetime - date.to_datetime).to_i
  end

  def days_until_today_text(date)
    days = days_until_today(date)
    if days.blank?
      '-'
    elsif days == 0
      'today'
    elsif days > 0
      "#{days} #{pluralize_based_on(days, 'day')} ago"
    elsif days < 0
      "<b>in #{-days} #{pluralize_based_on(days, 'day')}</b>".html_safe
    end
  end

  # Wrapper for descriptive link
  def descriptive_issue_link(issue)
    self.send("descriptive_#{issue.class.name.underscore}_link", issue)
  end

  def descriptive_bug_link(bug)
    desc = ["(#{bug.component_name})", bug.bug_status, bug.short_desc].collect {|c| ERB::Util.h(c)}.join(' - ').html_safe
    "#{bug_link(bug)} #{desc}".html_safe
  end

  def descriptive_jira_issue_link(jira_issue)
    desc = [jira_issue.status, jira_issue.summary].collect {|c| ERB::Util.h(c)}.join(' - ').html_safe
    "#{jira_issue_link(jira_issue)} #{desc}".html_safe
  end

  def ensure_utf8(text)
    "#{text}".encode(Encoding::UTF_8, :invalid => :replace, :undef => :replace, :replace => '')
  end

  def errata_link(errata)
    link_to(errata.advisory_name, { :action => 'view', :controller => 'errata', :id => errata}, :title => errata.synopsis, :class=>'advisory_link')
  end

  # Given an Enumerable of objects, returns a comma separated list of their ids. Common for bugzilla links
  def idlist(objects)
    safe_join(objects.collect {|o| o.id}, ',')
  end

  # For display lists like this: "foo, bar and baz"
  # If elide_after is specified, elements after that index are
  # replaced with "and <n> more"
  def display_list_with_and(list, opts={})
    if (n=opts[:elide_after]).present? && n >= 1 && list.length > n
      removed = list.length - n
      return display_list_with_and(list[0..(n-1)] + ["#{removed} more"], opts.merge(:elide_after => nil))
    end

    case list.length when 0
      ""
    when 1
      list.first
    else
      and_word = opts[:and] || 'and'
      and_word = '&' if opts[:ampersand]
      "#{list[0..-2].join(', ')}#{',' if opts[:oxford_comma]} #{and_word} #{list.last}"
    end
  end

  # Allow some html in flash message text
  # (Used in app/view/layouts/_flash)
  def flash_message_sanitize(message)
    sanitize(message, :tags=>%w[p div span a ul li b i br hr], :attributes=>%w[class href data-modal-id]).full_stop
  end

  #
  # (Mainly used for showing embargo dates in bold red if the advisory is
  # currently embargoed)
  #
  def highlight_text_if(condition, text, opts={})
    highlight_class = opts.fetch(:highlight_class, 'bold')
    content_tag(:span, text, :class => (condition ? highlight_class : nil))
  end

  def bold_red_if(condition, text, opts={})
    highlight_text_if(condition, text, :highlight_class => 'bold red')
  end

  #
  # Used in just one place, main_layout
  #
  # I'm not clear on which pages use @page_name vs @page_title. It's a
  # bit mixed up at the moment, but it doesn't matter too much.
  # Worry about it later...
  #
  # @secondary_nav_selected_name is set in get_individual_errata_nav
  # so actually it only effective for advisory tabs.
  #
  def page_title_helper
    strip_tags(safe_join([
      Settings.env_indicator_text,
      @secondary_nav_selected_name,
      (@errata_title || @page_title_override || @page_title || @page_name),
      'Errata Tool',
    ].compact.uniq, ' - '))
  end

  def is_holiday_season?
    Time.now.month == 12 && Settings.enable_xmas_scheme
  end

  #
  # Used in main_layout and /user/preferences
  # Determines main nav bar color
  #
  def color_scheme_helper(opts={})
    color_scheme = user_pref(:color_scheme)
    color_scheme = Settings.default_color_scheme if color_scheme.blank? && !opts[:allow_blank]
    color_scheme = 'red' if color_scheme == 'xmas' && !is_holiday_season?
    color_scheme
  end

  # Renders an H1 header to the page title
  def page_title_h1
    # @_already_shown_h1 is a hack to prevent duplicate headings. # See main_layout
    @_already_shown_h1 = true
    content_tag(:h1, @page_title)
  end

  def n_thing_or_things(count, thing)
    count = count.length if !count.is_a?(Fixnum)
    "#{count} #{pluralize_based_on(count, thing)}"
  end

  def n_thing_or_things_percent(count, total, thing)
    count = count.length if !count.is_a?(Fixnum)
    "#{n_thing_or_things(count, thing)} <span class='light'>(#{number_to_percentage(100.0*count/total, :precision=>0)})</span>".html_safe
  end

  def pluralize_if(condition, text)
    condition ? text.pluralize : text
  end

  def pluralize_based_on(count, text)
    count = count.length if !count.is_a?(Fixnum)
    # note: You say '0 rabbits' rather than '0 rabbit', hence the count == 0
    pluralize_if(count.abs > 1 || count == 0, text)
  end

  def word_if_plural(count,singular,plural)
    count = count.length if !count.is_a?(Fixnum)
    count.abs > 1 ? plural : singular
  end

  def was_were(count)
    word_if_plural(count,'was','were')
  end

  def reversed_if(condition, list)
    condition ? list.reverse : list
  end

  def post_link(title, action, object, opts={})
    link_to(title, {:action => action, :id => object}, opts.merge(:method => :post) )
  end

  def post_link_confirm(title, action, object, confirm = 'Are You Sure?', opts = {})
    # Need this for remove_build, reload_build and reselect_build
    is_pdc = object.is_a?(PdcErrataReleaseBuild) ? 1 : 0
    link_to(title, {:action => action, :id => object, :is_pdc => is_pdc}, opts.merge(:confirm => confirm,  :method => :post) )
  end

  def get_current_url
    "#{request.protocol}#{request.host_with_port}#{request.fullpath}"
  end

  def partial_exists?(partial_name, view_folder)
    lookup_context.template_exists?(partial_name, view_folder, true)
  end

  # Full path so you can use it in emails
  def get_full_advisory_link(errata)
    "#{request.protocol}#{request.host_with_port}/advisory/#{errata.id}"
  end

  def rpmdiff_run_link(run, text)
    link_to(text, { :action => 'show', :controller => 'rpmdiff', :id => run})
  end

  def rpmdiff_result_link(result, text)
    link_to(text, { :action => 'show', :controller => 'rpmdiff', :id => result.rpmdiff_run.id, :result_id => result.id})
  end

  def get_rpmdiff_result_link(result)
    "#{request.protocol}#{request.host_with_port}/rpmdiff/show/#{result.rpmdiff_run.id}?result_id=#{result.id}"
  end

  def dist_url(dist, product_version=nil)
    # Likely to be a PDC::V1::ContentDeliveryRepo
    return dist.url if dist.respond_to?(:url)

    # ..or one of the Channel or CdnRepo subclasses
    product_version ||= dist.product_version
    case dist
    when Channel
      product_version_channel_url(product_version, dist)
    when CdnRepo
      product_version_variant_cdn_repo_url(product_version, dist.variant, dist)
    end
  end

  def short_date(date, text_if_nil='')
    return text_if_nil if date.nil?
    date.strftime('%Y-%m-%d')
  end

  def nice_date(date, text_if_nil='')
    return text_if_nil if date.nil?
    date.to_s(:Y_mmm_d).upcase # not sure about the upcase but have used that elsewhere so go with it for now..
  end

  def long_date(date, text_if_nil='')
    return text_if_nil if date.nil?
    date.strftime('%Y-%m-%d %H:%M')
  end

  def toggle_div(div, elem=nil)
    toggle = "$('##{div}').toggle();"
    return toggle if elem.nil?
    toggle += "$('##{elem}').toggleClass('currently_hiding');"
  end

  def unassigned_errata_link
    return '' unless User.current_user.in_role?('qa')
    count = Errata.unassigned_count
    return '' unless count > 0
    link_to("There are #{count} unassigned errata.", :action => :unassigned, :controller => :errata)
  end

  # See config/initializers/wrap_text.rb
  # (Consider also using Rails' built-in helper `word_wrap`)
  def wrap_text(txt, col = 75)
    txt.wrap_text(col)
  end

  # Attempts to remove single line breaks but keep double-line "paragraph" breaks.
  # (Wouldn't work well for text with markdown style lists)
  def unwrap_text(text)
    text.gsub(/([^\n])\n([^\n])/, '\1 \2')
  end

  def yes_no_glyph(condition, no=:no, yes=:yes)
    content_tag(:span, status_icon(condition ? yes : no), :class=>"step-status with-border step-status-#{condition ? 'ok' : 'block'}")
  end

  #
  # I think I've written this before elsewhere.
  # TODO: find and combine..
  #
  def yes_no_message(condition, yes_message='Yes', no_message='No', note=nil)
    %{#{yes_no_glyph(condition)} #{condition ? yes_message : no_message}#{"<br/><span class='light small'>#{note}</span>" if note}}.html_safe
  end

  def yes_no_icon(condition)
    yes_no = (condition ? 'yes' : 'no')
    image_tag("icon_#{yes_no}.gif", :alt => yes_no)
  end

  def yes_no_icon_and_text(condition, yes_text='Yes', no_text='No')
    "#{yes_no_icon(condition)} #{condition ? yes_text : no_text}".html_safe
  end

  def lock_icon(condition)
    content_tag(:span, nil, :class => "fa fa-#{condition ? 'lock' : 'unlock'}")
  end

  def lock_icon_and_text(condition, locked_text='Locked', unlocked_text='Unlocked')
    "#{lock_icon(condition)} #{condition ? locked_text : unlocked_text}".html_safe
  end

  def dash_if_blank(value)
    value.present? ? value.to_s : '-'
  end

  def none_text(opts={})
    content_tag(opts[:elem]||:i, opts[:text]||'none', :class=>(opts[:class]||'small light'))
  end

  def block_or_none_text(things, opts={})
    if things && things.present? && !things.empty?
      yield things
    else
      none_text(opts)
    end
  end

  def yes_no_td(condition)
    %{<td style="text-align:center">#{yes_no_icon(condition)}</td>}.html_safe
  end

  #
  # Display state/status
  #
  def state_display(errata_or_state, opts={})
    state = (errata_or_state.is_a?(Errata) ? errata_or_state.status : errata_or_state)
    %{<span class="state_indicator state_indicator_#{state.to_s.downcase}">#{State.nice_label(state,opts)}</span>}.html_safe
  end

  def state_transition_display(from_state, to_state)
    %{#{state_display(from_state, :short=>true)} &rarr; #{state_display(to_state, :short=>true)}}.html_safe
  end

  #
  # Display indicator of blocked or need info for use in advisory lists
  #
  def blocked_or_info_display(errata)
    [
      (%{<span class="blocked_indicator blocked_indicator_blocked"
        title="Blocked on #{errata.active_blocking_issue.blocking_role.name.capitalize}: #{errata.active_blocking_issue.summary}">BLOCK!</span>} if errata.is_blocked?),

      (%{<span class="blocked_indicator blocked_indicator_info_req"
        title="Info requested from #{errata.active_info_request.info_role.name.capitalize}: #{errata.active_info_request.summary}">Info?</span>} if errata.info_requested?),

    ].compact.join.html_safe
  end

  # Used to add an id to a tr element in _bz_row
  def object_row_id(object)
    "#{object.class.to_s.underscore}_#{object.id}" if object.is_a?(ActiveRecord::Base)
  end

  def bug_metadata(bug)
    metadata = [ h(bug.short_desc) ]
    if bug.has_metadata?
      metadata << '<br />'
      metadata << 'blocker' if bug.is_blocker?
      metadata << 'exception' if bug.is_exception?
      metadata << h(bug.keywords) unless bug.keywords.empty?
      metadata << safe_join(bug.issuetrackers.split(',').map {|i| it_link(i.strip)}, ', ') unless bug.issuetrackers.empty?
    end
    metadata.join('&nbsp; ').html_safe
  end

  #
  # For the link icons in docs queue.
  # (Just to tidy up the view template a bit).
  #
  # (Actually used outside of docs queue now...)
  #
  def docs_queue_icon_link(opts)
    link_to(
      "#{image_tag(opts[:icon], :border=>0)}#{opts[:label] if opts[:label]}".html_safe,
      { :controller => opts[:controller], :action => opts[:action], :id => opts[:id] },
      { :target => (opts[:this_window] ? '' : '_blank'), :title => opts[:title], :class => 'icon_link' }
    )
  end

  #
  # Based on kerberos auth (so different to current_user)
  #
  def guess_remote_user
    result = if Rails.env.development?
               # No kerberos so fudge it
               User.fake_devel_user.short_name
             else
               # This is defined in application_controller
               remote_user
             end

    # Probably doesn't matter, but let's ensure we always return
    # a non-empty string to prevent any possible weirdness...
    result.present? ? result : 'user'
  end

  #
  # Used in _request_access_howto.html.erb
  #
  def orgchart_url_for_user(user_name=nil)
    user_name ||= guess_remote_user
    user_name.strip!
    user_name.sub!(/@redhat.com$/i,'')
    "https://people.engineering.redhat.com/orgchart?uid=#{user_name}"
  end

  #
  # Simple helper for table rows
  # Use :labels=>true to make every even td a label
  #
  def table_row_helper(cells, opts={})
    if cells[0] == :divider
      # this is not very nice..
      "<tr><td colspan='#{cells[1]}' class='divider'><div></div></td></tr>".html_safe
    else
      # Tried making this with content_tag but couldn't get the html_safe to work right... :S
      "<tr>#{cells.compact.each_with_index.map{ |cell, i|
        # ... fixme
        if cell.is_a? Hash
          cell_content = ERB::Util.h(cell[:content])
          cell_opts = cell
        else
          cell_content = ERB::Util.h(cell)
          cell_opts = {}
        end
        classes = []
        classes << 'small_label' if i.even? && opts[:labels] && cells.length > 1
        classes << 'pre'   if cell_opts[:pre]
        classes << 'tiny'  if cell_opts[:tiny]
        classes << 'small' if cell_opts[:small]
        classes << 'bold'  if cell_opts[:bold]
        classes << 'light' if cell_opts[:light]
        classes << 'superlight' if cell_opts[:superlight]

        styles = []
        styles << 'padding-left:2em' if i != 0 && i.even?
        # Yuck, this is nuts..
        "<td" +
          "#{" colspan='#{cell_opts[:colspan]}'" if cell_opts[:colspan]}" +
          " style='#{safe_join(styles, ';')}'" +
          " class='#{safe_join(classes, ' ')}'" +
        ">#{cell_content}"+
        "#{"<br/><span class='small light'>#{cell_opts[:note]}</span>" if cell_opts[:note]}" + # even more hackery
        "</td>"
      }.join("\n")}</tr>".html_safe
    end
  end

  def table_rows_helper(rows, opts={})
    result = safe_join(rows.compact.map{ |row| table_row_helper(row,opts) }, "\n")
    result = "<table class='#{opts[:table]}'>#{result}</table>" if opts[:table]
    result.html_safe
  end

  # Does rails already have one of these???
  # NB: this is terrible for formatted text or or html..
  def string_trunc(string, length=30)
    string.length < length ? string : string[0..length] + '...'
  end

  def line_trunc(string, length=4)
    lines = string.split("\n")
    if lines.count > length
      lines[0...length].join("\n").strip + "\n..."
    else
      string
    end
  end

  #
  # Use a bootstrap popover
  #
  # Displays truncated content with popover revealing the full content.
  #
  def content_popover_helper(content, title, link='#', opts={})
    limit_to    = opts[:limit_to] || 45
    placement   = opts[:placement] || 'right'
    manual_text = opts[:manual_text]
    css_class   = opts[:class] || []
    css_class   << 'popover-test'

    data = {:content => content, :placement => placement, :'original-title' => title}
    # click to trigger popover box
    data.merge!({:trigger => 'click'}) if opts.fetch(:click, false)

    hash = data.inject({}) {|h, (k,v)| h["data-#{k}"] = v; h}
    hash.merge!({:rel=>'popover top', :class=> css_class.join(" "), :target=>opts[:target]})

    # Fudge the limit a bit because we don't really want to reveal just one or two extra chars..
    if content.length > limit_to + 5 || manual_text
      anchor_text = manual_text || "#{content[0...limit_to]}..."
      if link=='#'
        # use <a> tag without href, see bug 1220640
        content_tag(:a, anchor_text, hash)
      else
        link_to(anchor_text, link, hash)
      end
    else
      content
    end
  end

  #
  # Make it easier distinguish between different environments
  # (See also config/initializers/settings.rb)
  #
  def env_banner_text
    Settings.host_based_banner_labels[request.env['SERVER_NAME']] || Settings.env_based_banner_labels[Rails.env]
  end

  def env_banner_alt_text
    "#{Rails.env}, #{request.env['SERVER_NAME']}"
  end

  #
  # A trick so you can have partials that take blocks.
  # Uses render :layout.
  #
  # Example:
  #   <%= block_render 'some_partial_with_a_yield', :foo => 123 do %>
  #     Any erb here...
  #   <% end %>
  #
  def block_render(_partial_name, _partial_locals={})
    render(:layout => _partial_name, :locals => _partial_locals) do
      yield
    end
  end

  #
  # We can use the controller (and action) to predict the currently
  # selected main nav item pretty accurately.
  #
  # If you need to override this just set @main_nav_selected in a
  # controller or action.
  #
  # Used in main_nav_link_helper to decide if a link should have
  # the 'selected' class to make it highlight to indicate it is
  # the current active menu item.
  #
  # Returns an element id which corresponds to an li tag id
  # in the main nav.
  #
  def main_nav_guess_current
    @main_nav_selected ||= case "#{controller.controller_name}:#{controller.action_name}"
    when /^errata:new/          ; 'main_new_errata'
    when /^errata:preview/      ; nil
    when /^errata/              ; 'main_list_errata'
    when /^reports/             ; 'main_dashboard'

    # Bugzilla, JIRA and shared issue tracking all goes in the same section
    when /^issues/              ; 'main_bugs'
    when /^bugs/                ; 'main_bugs'
    when /^jira_issues/         ; 'main_bugs'

    # These ones are in docs controller but really they are advisory views...
    # (See if anyone complains about it...)
    when /^docs:show/           ; 'main_list_errata'
    when /^docs:diff_history/   ; 'main_list_errata'
    when /^docs:doc_text_info/  ; 'main_list_errata'

    when /^docs/                ; 'main_docs'
    when /^rpmdiff:list_autowaive/  ; 'main_rpmdiff'
    when /^rpmdiff:show_autowaive/  ; 'main_rpmdiff'
    when /^rpmdiff:list/        ; 'main_list_errata'
    when /^rpmdiff:show/        ; 'main_list_errata'
    when /^rpmdiff:waivers_for_errata/ ; 'main_list_errata'
    when /^rpmdiff/             ; 'main_rpmdiff'
    when /^tps:errata_results/  ; 'main_list_errata'
    when /^tps:rhnqa_results/   ; 'main_list_errata'
    when /^tps/                 ; 'main_tps'
    when /^release_engineering/ ; 'main_releng'
    when /^admin/               ; 'main_admin'
    when /^security/            ; 'main_secalert'
    when /^package_restrictions/; nil
    when /^package/             ; 'main_pkgbrowser'
    # Make some attempt at getting it right for the stuff under Admin menu
    when /^(user|product|rhn|release)/
      'main_admin'
    else
      # Give up
      ''
    end
  end

  #
  # TODO: This basically repeating information that is already defined in _mainmenu_links.
  # Should DRY this up in some way... Worry about it later.
  #
  def guess_page_title
    case main_nav_guess_current
    when 'main_list_errata' ; 'Advisories'
    when 'main_list'        ; 'QA Requests'
    when 'main_dashboard'   ; 'Dashboard'
    when 'main_bugs'        ; 'Advisory Bugs'
    when 'main_docs'        ; 'Documentation Queue'
    when 'main_rpmdiff'     ; 'RPMDiff'
    when 'main_tps'         ; 'TPS'
    when 'main_releng'      ; 'Release Engineering'
    when 'main_admin'       ; 'Administration'
    when 'main_secalert'    ; 'Security'
    when 'main_pkgbrowser'  ; 'Packages'
    else                    ; nil
    end
  end

  #
  # A convience wrapper for User.current_user.in_role?
  #
  # You can use a prefix of "not_" to mean not in this role.
  # (The main purpose of this helper is to make _mainmenu_links
  # easy to read and maintain)
  #
  # This is a bit different to User#in_role? in that you can't
  # give it more than one role. Maybe the logic should be moved
  # in to the User model.
  #
  def has_role?(role)
    # I want to be able to use a symbol
    role = role.to_s

    case role
    when 'everyone'
      true

    when 'readonly'
      User.current_user.is_readonly?

    when 'not_readonly'
      !User.current_user.is_readonly?

    else
      # The sub! returns nil if no substition was made
      negated = !!role.sub!(/^not_/,'')

      # It's an XOR, cool huh? ;)
      negated ^ User.current_user.in_role?(role)
    end
  end

  #
  # Used to render links in _mainmenu_links partial
  #
  def main_nav_link_helper(role,link_id,link_text,link_title,link_details)
    if has_role?(role)
      ("<li id='#{link_id}'#{" class='active'" if main_nav_guess_current == link_id}>" +
        link_to(link_text, link_details, :title => link_title) +
      "</li>").html_safe
    else
      ""
    end
  end

  #
  # For showing a user as a mailto link
  #
  def nice_mailto_link(user, link_text_method=:short_name)
    return '-' unless user
    mail_to(user.login_name, user.send(link_text_method), :title => user.to_s)
  end

  # It's wrong to put the span small around this but I am
  # hacking on app/views/errata/details, fixme later
  def longer_mailto_link(user)
    content_tag(:span,nice_mailto_link(user, :short_to_s),:class=>'small')
  end

  #
  # Use overflow hidden but add a title so that mouseover shows the whole text...
  #
  def width_limited_with_mouseover(text, width, css_class='', id=nil)
    html_options = {
      :class => "clipwidth #{css_class}",
      :title => text,
      :style => "max-width:#{width}"
    }
    html_options[:id] = id unless id.nil?
    content_tag :div, text, html_options
  end

  # See http://twitter.github.com/bootstrap/base-css.html#icons
  def glyph_icon(icon_name)
    %{<i class="icon-#{icon_name}"></i>}.html_safe
  end

  # A helper for using glyph_icons
  def status_icon(status)
    glyph_icon(
      case status
      when TrueClass, :ok, :yes
        'ok'
      when :wait, :waive
        #'question-sign'
        'pause'
      when :block
        'ban-circle'
      when :na
        'stop'
      when :info
        'info-sign'
      when FalseClass, NilClass, :no
        'remove'
      else
        status.to_s
      end
    )
  end

  #
  # Helpers for hiding/showing things based on a user pref
  #
  def hide_style_if(condition)
    condition ? 'display:none;' : ''
  end

  def show_style_if(condition)
    hide_style_if(!condition)
  end

  def hide_if_user_pref(pref_name)
    hide_style_if(user_pref(pref_name))
  end

  def show_if_user_pref(pref_name)
    show_style_if(user_pref(pref_name))
  end

  #
  # For indicating we are waiting on ajax
  # Starts hidden.
  #
  def wait_spinner(element_id=nil, extra_style=nil)
    image_tag('wait_spinner.gif', :id=>element_id, :class=>'wait-spinner', :style=>['display:none;', extra_style].compact.join)
  end

  #
  # It kind of sucks that you have to specify type and state or else
  # get nothing. Why not have a default when no type or state is specified?
  # That is how the rest of them work.. fixme later :S
  #
  # NB: if you use this you need to supply at least one show_type_* => '1' and at least
  # one show_state_* => '1' otherwise you get no advisories.
  #
  # A typical way to do this is to use one of the methods below that call this one.
  #
  # Example use:
  #  <%= filter_link_helper_all(release.name, {'release'=>release.id}) %>
  #
  # See leaderboard.rhtml for some more examples.
  #
  def filter_link_helper(text, filter_params={}, other_params={}, opts={})
    all_statuses = opts.delete(:all_statuses)
    link_to(
      text,
      { :controller=>:errata, :action=>:index }.
        merge(other_params).
        merge(:errata_filter=>{:filter_params=>filter_params}),
      opts
    )
  end

  #
  # You don't want to have to put all these ugly FILTER_DEFAULTS_ALL in your views..
  #
  def filter_link_helper_all(text, filter_params={}, other_params={}, opts={})
    filter_link_helper(text, filter_params.merge(ErrataFilter::FILTER_DEFAULTS_ALL), other_params, opts)
  end

  def filter_link_helper_default(text, filter_params={}, other_params={}, opts={})
    filter_link_helper(text, filter_params.merge(ErrataFilter::FILTER_DEFAULTS), other_params, opts)
  end

  def filter_link_helper_all_types(text, filter_params={}, other_params={}, opts={})
    filter_link_helper(text, filter_params.merge(ErrataFilter::EVERY_TYPE), other_params, opts)
  end

  # Returns links to client-side actions intended to be embedded within a table header.
  # Example:
  # <td>Name<br/><%= th_actions(
  #   'Sort Ascending', 'table_sort($("#mytable"), true)',
  #   'Sort Descending', 'table_sort($("#mytable"), false)'
  # )%></td>
  def th_actions(*args)
    return '' if args.empty?
    th_header = <<-END
<span class="actions">
  #{args.each_slice(2).map do |text,js|
    %Q{<a onclick="#{ERB::Util.h js}">#{ERB::Util.h text}</a>}
  end.join(' - ')}
</span>
END
    return th_header.html_safe
  end

  def modal_link(label, path)
    link_to(
      label,
      "#",
      :class => "et-ui-ajax-on-click toggle-modal",
      :data => { :"ajax-request-url" => path }
    )
  end

  def dropdown_button_helper(menu_links, opts = {})
    btn_class = ["btn btn-default dropdown-toggle", opts.delete(:class)].compact.join(" ")
    content_tag(:div, {:class => "btn-group"}.merge(opts)) do
      safe_join([
        button_tag("type" => "button", "class" => btn_class, "data-toggle" => "dropdown", "aria-expanded" => "false") do
          safe_join(["Action", content_tag(:span, "", :class => "caret")], ' ')
        end,
        content_tag(:ul, {:class => "dropdown-menu", :role => "menu"}) do
          safe_join(
            menu_links.map do |link|
              content_tag(:li) do
                link
              end
            end, '')
        end
      ], '')
    end
  end

  def bz_row_helper(name, opts = {})
    return nil if name.nil?
    options = opts.dup
    tag = (method = options.delete(:method)) ? self.send(method, name) : {:content => name}
    tag.deep_merge!({:options => {:style => "width:50px"}})
    tag.deep_merge!({:options => options}) if options.any?
    tag
  end

  def panel_helper(title, message, panel_type = 'info')
    content_tag(:div, :class => "panel panel-#{panel_type}") do
      p_h = content_tag(:div, :class => "panel-heading") do
        content_tag(:span, title)
      end
      p_b = content_tag(:div, :class => "panel-body small") do
        message
      end
      safe_join([p_h, p_b])
    end
  end

  # Customize rendering of a form field with validation errors.
  #
  # The default field_with_errors simply wraps the field in a div.
  # This customized implementation also includes the error message
  # next to the field.
  #
  def field_with_errors(html_tag, instance)
    errors = instance.error_message.flatten

    if errors.length == 1
      error_content = content_tag(:span) { errors[0] }
    else
      error_content = content_tag(:ul) do
        safe_join(errors.map{ |e| content_tag(:li, e) })
      end
    end

    safe_join([
      content_tag(:div, :class => 'field_with_errors') { html_tag },
      content_tag(:div, :class => 'field_errors')      { error_content },
    ])
  end

  # Static version of above for use with config.action_view.field_error_proc
  def self.field_with_errors(html_tag, instance)
    # This is ugly but let me explain...
    #
    # ActionView by design has a hook for customizing the rendering of fields
    # with errors: field_error_proc
    #
    # Unfortunately the only two arguments passed to the proc have no method to
    # get a reference to the current view context, therefore there is no way to
    # use the standard helper methods such as content_tag etc.  Examples of
    # using this hook are usually using raw HTML, e.g. in
    # http://guides.rubyonrails.org/v3.2/configuring.html
    #
    # I think this is unacceptable and it's preferable to use this trick to get
    # a handle to the view context, working around the design oversight.
    t = instance.instance_variable_get('@template_object')
    t.field_with_errors(html_tag, instance)
  end
end

ApplicationHelper.module_eval do
  # Allow the followings module methods to call directly without include
  [:pluralize_based_on, :pluralize_if, :n_thing_or_things].each do |method|
    module_function method
    # module_function change instance methods to private, so change it back to public
    public method
  end
end
