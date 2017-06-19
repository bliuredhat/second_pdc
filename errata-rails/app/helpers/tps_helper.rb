module TpsHelper

  #
  # See Bz 745794, Bz 1140631
  #
  def tps_state_help_link(tps_job)
    state = tps_job.tps_state.state

    link = case state
    when 'BAD'
      case when tps_job.rhnqa?
        'http://wiki.test.redhat.com/ErrataWorkflow/ClosingErrata#DistQATPSFinishedAndFailed'
      else
        'http://wiki.test.redhat.com/ErrataWorkflow/PreparingToTest#TPSFinishedAndFailed'
      end
    when 'NOT_STARTED'
      'http://wiki.test.redhat.com/Faq/Tps/TpsJobInNotStarted'
    end

    klass = "tps_#{state.downcase}"

    if link
      # Link to some TPS job help
      link_to(icon_btn_text_right(state, 'info-sign'), link,
        :target=>'_blank', :class=>klass, :title=>"Click for information on #{state.downcase} TPS jobs")
    else
      # Just show the text in a span
      content_tag(:span, state, :class=>klass)
    end
  end

  def tps_job_validity_icon(job_id, is_valid_for_tps, tps_errors)
    # hidden span for tablesort sorting
    sorting = content_tag(:span, is_valid_for_tps ? '1' : '0', :style => "display:none;")
    # Return yes icon if the job is a valid TPS job
    return sorting + yes_no_icon(is_valid_for_tps) if is_valid_for_tps
    # Otherwise, show alert icon with popover message.
    sorting + content_popover_helper(
      render("tps/job_errors", :errors => tps_errors.values.flatten),
      'This job might not start due to the error/s below:', "##{job_id}",
      { :limit_to => 0,
        :manual_text => image_tag('icon_alert.gif'),
        :placement => 'bottom',
        :class => ["help-cursor", "tps_error"],
        :click => true
      }
    )
  end

  def link_to_ssh_host(host, opts={})
    return '' if host.blank?
    link_to(host, "ssh://root@#{host}", opts)
  end
end
