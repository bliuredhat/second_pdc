class RpmdiffWaiverObserver < ActiveRecord::Observer
  observe RpmdiffWaiver

  def after_create(w)
    created_waivers << w
  end

  def after_update(w)
    if w.acked_changed? && w.acked?
      approved_waivers << w
    end
  end

  def after_rollback(*args)
    clear_tls
  end

  def after_commit(*args)
    all_waivers = created_waivers + approved_waivers
    return if all_waivers.empty?

    all_waivers = all_waivers.sort_by{|w| [
      created_waivers.include?(w) ? 0 : 1,
      w.is_unwaive? ? 0 : 1,
      w.package.name,
      w.rpmdiff_test.description
    ]}

    comments = {}
    all_waivers.each do |w|
      errata = w.rpmdiff_run.errata
      (comments[errata] ||= []) << comment_for(w)
    end

    comments.each do |errata,texts|
      text = texts.join("\n\n")
      errata.comments << RpmdiffComment.new(:text => text)
    end
  ensure
    clear_tls
  end

  private
  def created_waivers
    Thread.current[:created_rpmdiff_waivers] ||= []
  end

  def approved_waivers
    Thread.current[:approved_rpmdiff_waivers] ||= []
  end

  def clear_tls
    created_waivers.clear
    approved_waivers.clear
  end

  def result_url(result)
    run_id = result.rpmdiff_run.run_id
    return "http://errata.devel.redhat.com/rpmdiff/show/#{run_id}?result_id=#{result.result_id}"
  end

  def run_comment_header(result)
    run_id = result.rpmdiff_run.run_id
    return "RPMDiff Run #{run_id}, test \"#{result.rpmdiff_test.description}\""
  end

  def was_approved?(w)
    approved_waivers.include?(w)
  end

  def action_for(w)
    if was_approved?(w)
      " waiver has been approved\n"
    else
      " has been #{w.is_unwaive? ? 'unwaived' : 'waived'}\n"
    end
  end

  def comment_for(w)
    result = w.rpmdiff_result
    out = run_comment_header(result) +
      action_for(w) +
      result_url(result)

    if was_approved?(w)
      if w.ack_description.present?
        out += "\n" + w.ack_description
      end
    else
      out += "\n" + w.description
    end

    out
  end
end
