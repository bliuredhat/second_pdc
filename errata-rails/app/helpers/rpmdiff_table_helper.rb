module RpmdiffTableHelper
  # This helper contains various functions which can be used to build up rpmdiff-related tables.

  def rpmdiff_waiver_qe_row(w, opts)
    r = w.rpmdiff_result
    form = opts.delete(:form)

    input = if form
      (%q{<div class="btn-group rpmdiff_ack_nack" data-toggle="buttons-checkbox">} + \
        %w{Approve Reject}.zip(%w{ok remove}).map do |text, icon|
          button_tag(icon_btn_text(text, icon), :type => 'button', :'data-id' => w.id, :'data-value' => text.downcase, :onclick => 'et_waiver_ack_button_clicked(event)', :class => 'btn ack')
        end.join + '</div>' + \
      hidden_field_tag("ack[#{w.id}]", nil, :'data-id' => w.id, :class => 'ack')).html_safe
    end

    {:options => opts, :content => [
      link_to(r.rpmdiff_run.id, :action => 'show', :id => r.rpmdiff_run, :result_id => r.id),
      {
        :content => %Q{
          <a class="clickable_row" onclick="et_toggle_rpmdiff_log(#{r.id})">
            <span id="rpmdiff_log_icon_#{r.id}" class="ui-icon ui-icon-carat-1-e" style="float: left"></span>
            &nbsp;
            #{h(w.rpmdiff_score.description)}
          </a>
        }.html_safe
      },
      "#{r.rpmdiff_test.description}" ,
      "#{r.rpmdiff_run.package_name}" ,
      "#{v = r.rpmdiff_run.old_version; v == 'NEW_PACKAGE' ? '-' : v}" ,
      "#{r.rpmdiff_run.new_version}" ,
      input
    ].compact}
  end

  def rpmdiff_waiver_dev_row(r, opts)
    form = opts.delete(:form)

    input = if form
      check_box(:request_waiver, r.id, :class => 'request_waiver', :'data-id' => r.id, :onchange => 'et_waiver_checkbox_changed(event)')
    end

    {:options => opts, :content => [
      link_to(r.rpmdiff_run.id, :action => 'show', :id => r.rpmdiff_run, :result_id => r.id),
      {
        :content => %Q{
          <a class="clickable_row" onclick="et_toggle_rpmdiff_log(#{r.id})">
            <span id="rpmdiff_log_icon_#{r.id}" class="ui-icon ui-icon-carat-1-e" style="float: left"></span>
            &nbsp;
            #{h(r.rpmdiff_score.description)}
          </a>
          #{hidden_field_tag("score[#{r.id}]", r.rpmdiff_score.id)}
        }.html_safe
      },
      "#{r.rpmdiff_test.description}" ,
      "#{r.rpmdiff_run.package_name}" ,
      "#{v = r.rpmdiff_run.old_version; v == 'NEW_PACKAGE' ? '-' : v}" ,
      "#{r.rpmdiff_run.new_version}" ,
      input
    ].compact}
  end

  def rpmdiff_ack_text_label
    # The text displayed next to the ack textarea is different depending on
    # whether approve or reject is currently selected.
    labels = [
      content_tag(:span, :class => 'approve-only') do
        'Optionally, provide a comment regarding this approval.'
      end,
      content_tag(:span, :class => 'reject-only') do
        'Please provide an explanation why these results should not be waived.'
      end,
    ]
    safe_join(labels)
  end

  def rpmdiff_waiver_ack_row(w, opts)
    klass = 'ack_text'
    id = w.id

    opts.merge!(:extra_class => klass, :'data-id' => id, :style => [opts[:style],'display:none'].join(';'))

    {:options => opts, :content => [
      '',
      {
        :options => {:class => 'rpmdiff_ack_text_label', :colspan => 2},
        :content => rpmdiff_ack_text_label,
      },
      {
        :options => {:class => klass, :colspan => 4},
        :content => text_area_tag("#{klass}[#{id}]", '')
      }
    ]}
  end

  def rpmdiff_waiver_request_row(r, opts)
    klass = 'waive_text'
    id = r.id

    opts.merge!(:extra_class => klass, :'data-id' => id, :style => [opts[:style],'display:none'].join(';'))

    {:options => opts, :content => [
      '',
      {
        :options => {:colspan => 2},
        :content => "Please enter an explanation if these changes are valid and intentional."
      },
      {
        :options => {:class => klass, :colspan => 4},
        :content => text_area_tag("#{klass}[#{id}]", 'This change is OK because ')
      }
    ]}
  end

  # This method accepts rpmdiff results (for dev view) or waivers (for QE view).
  def rpmdiff_waiver_log_row(rw, opts)
    r = rw.kind_of?(RpmdiffResult) ? rw : rw.rpmdiff_result
    content = render('render_rpmdiff_result_details', :current_result => r)
    form = opts.delete(:form)
    cols = form ? 7 : 6
    opts.merge!(:extra_class => 'result_log', :'data-id' => r.id, :style => [opts[:style],'display:none'].join(';'))

    unless @waiver_history[r.id].blank?
      waivertable = render :partial => 'embedded_waiver_history', :locals => {:waivers => @waiver_history[r.id]}
      content = "#{waivertable}<br/>#{content}".html_safe
    end

    {:options => opts, :content => [
      {
        # wrapper div looks dumb, but we want to customize the padding and there's an !important
        # padding rule already for .bug_list td
        :content => "<div>#{content}</div>".html_safe,
        :options => {:class => 'rpmdiff_log', :colspan => cols},
      }
    ]}
  end

  def rpmdiff_waiver_history_headers(opts = {})
    [
      'RPMDiff Run',
      ('Test' if opts[:show_test]),
      ('Errata' if opts[:show_errata]),
      'Waived By',
      'When',
      'Waive Text',
      'Approved By',
      'Approval Text',
    ].compact
  end

  def rpmdiff_waiver_history_row_func(opts = {})
    lambda do |w|
     [
       link_to(w.rpmdiff_run.id, :action => 'show', :id => w.rpmdiff_run,
               :result_id => w.rpmdiff_result),
       (w.rpmdiff_test.description if opts[:show_test]),
       (link_to(w.rpmdiff_run.errata_nr, :action => :show, :controller => :errata,
                :id => w.rpmdiff_run.errata_id) if opts[:show_errata]),
       w.user.to_s,
       short_date(w.waive_date),
       w.description,
       (w.acked_by ? w.acked_by.to_s : '--'),
       (w.ack_description || '--')
     ].compact
    end
  end
end
