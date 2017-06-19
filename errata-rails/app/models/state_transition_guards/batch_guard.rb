class BatchGuard < StateTransitionGuard
  def transition_ok?(errata)
    batch = errata.batch

    # OK if not assigned to a batch
    return true if batch.nil?

    # OK if assigned to an inactive batch
    return true unless batch.is_active?

    # RHSAs should not have batch set anyway
    return true if errata.is_security?

    # Not OK if release date has not been set
    return false if batch.release_date.nil?

    # Not OK if release date is in the future
    return false if batch.future_release_date?

    # Let batch blockers through
    return true if errata.is_batch_blocker?

    # All blockers must transition to PUSH_READY first
    return false if batch.blockers.any?

    true
  end

  def ok_message(errata=nil)
    return 'Advisory is not part of a batch' if errata && !errata.batch
    'Batch checks complete'
  end

  def failure_message(errata=nil)
    return 'Batch checks incomplete' unless errata

    batch = errata.batch
    return 'Advisory is not part of a batch' unless batch

    batch_messages = []
    batch_messages << 'Batch has no release date' if batch.release_date.nil?
    batch_messages << 'Batch release date is in the future' if batch.future_release_date?
    batch_messages << "Batch is blocked by #{format_errata_list(batch.blockers)}" if batch.blockers.any?

    if batch_messages.any?
      return batch_messages.join(', ')
    end

    return 'Batch checks failed'
  end

  private

  def format_errata_list(errata)
    if errata.count > 3
      return "#{errata.count} advisories"
    elsif errata.count == 1
      return "advisory #{errata.first.fulladvisory}"
    else
      return "#{errata.count} advisories (#{errata.map(&:fulladvisory).sort.join(', ')})"
    end
  end

end
