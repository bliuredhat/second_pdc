module TpsTests
  extend ActiveSupport::Concern
  included do
    has_one :tps_run,
    :conditions => 'current = 1'
  end

  # True if TPS should be scheduled
  # (Might be non-blocking)
  def requires_tps?
    return false if self.text_only?
    return false unless self.has_rpms?
    self.state_machine_rule_set.test_requirements.include?('tps')
  end

  def tps_finished?
    return true unless self.requires_tps?
    return true unless self.tps_run
    return self.tps_run.tps_jobs_finished?
  end

  def tpsrhnqa_finished?
    return true unless self.requires_tps?
    return true unless self.tps_run
    return self.tps_run.distqa_jobs_finished?
  end

  def tps_guards_in_current_state
    self.state_machine_rule_set.guards_in_state(self.status, :tps)
  end

  def tps_rhnqa_guards_in_current_state
    self.state_machine_rule_set.guards_in_state(self.status, :tps_rhnqa)
  end

  def should_auto_schedule_tps?(rhnqa = false)
    rule = self.state_machine_rule_set.test_requirements
    option = rhnqa ? "TpsDistQAManualOnly" : "TpsManualOnly"
    !rule.include?(option)
  end

  def invalid_on_main_stream?
    tps_stream = variant.determine_tps_stream.first
    return false unless tps_stream.tps_stream_type.try(:name) == 'Main'
    release_type = respond_to?(:short_release_type) ? short_release_type : short_type
    # Main stream if release_type is EUS or Longlife
    return true if release_type.in?(%w{EUS LongLife})
    # - Channel/Repo belonging to the z-stream product,and the related RHEL product version had been disabled
    #   e.g. z-stream to z-stream eus,  RHEL-7.2.z was disabled and RHEL-7.2.EUS was created and enabled
    return variant.product_version.is_zstream? && !variant.rhel_variant.product_version.enabled?
  end

end
