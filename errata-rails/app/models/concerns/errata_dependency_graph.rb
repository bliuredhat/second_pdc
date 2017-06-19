module ErrataDependencyGraph
  extend ActiveSupport::Concern
  #
  # (The .compact helps prevent exceptions if a circular dependency is somehow
  # created. It's because the dependency_graph uses a nil when the recursion
  # depth is reached. Hopefully user won't be able to create a circular depencency
  # but in case they do, this might help)
  #
  def dependency_graph
    DependencyGraph::Errata.new(self)
  end

  #
  # These other advisories could potentially block this advisory.
  #
  def possibly_blocked_by
    dependency_graph.blocked_by.compact
  end

  #
  # This advisory could potentially block these other advisories.
  #
  def possibly_blocks
    dependency_graph.blocks.compact
  end

  #
  # If an advisory has reached one of these statuses then it no longer blocks anything.
  #
  def in_nonblocking_status?
    self.status_in?(:PUSH_READY, :IN_PUSH, :SHIPPED_LIVE)
  end

  #
  # These other advisories are currently blocking this advisory
  # (from moving to PUSH_READY).
  #
  def currently_blocked_by
    possibly_blocked_by.reject(&:in_nonblocking_status?)
  end

  #
  # These other advisories are currently blocking this advisory
  # from pushing to RHN stage.
  #
  def currently_blocked_for_rhn_stage_by
    # (No need to be blocked if we don't push to RHN stage)
    return [] unless self.supports_rhn_stage? || self.supports_rhn_live?
    # If the dependency is already pushed to RHN stage then it doesn't block
    possibly_blocked_by.reject(&:has_pushed_rhn_stage?)
  end

  #
  # These other advisories are currently blocking this advisory
  # from pushing to CDN stage.
  #
  def currently_blocked_for_cdn_stage_by
    # (No need to be blocked if we don't push to CDN stage)
    return [] unless self.supports_cdn_stage? || self.supports_cdn?
    # If the dependency is already pushed to CDN stage then it doesn't block
    possibly_blocked_by.reject(&:has_pushed_cdn_stage?)
  end

  #
  # These other advisories are currently blocking this advisory
  # from pushing to CDN docker stage.
  #
  def currently_blocked_for_cdn_docker_stage_by
    # (No need to be blocked if we don't push to CDN docker stage)
    return [] unless self.supports_cdn_docker_stage? || self.supports_cdn_docker?
    # If the dependency is already pushed to CDN docker stage then it doesn't block
    possibly_blocked_by.reject(&:has_pushed_cdn_docker_stage?)
  end

  #
  # These are other advisories that this advisory should block,
  # (i.e. prevent from moving to PUSH_READY)
  #
  def currently_blocks
    return [] if in_nonblocking_status?
    # Otherwise we block everything we could block
    possibly_blocks
  end

  #
  # These are other advisories that would have their dependency rules
  # violated if this advisory was moved to a blocking status.
  #
  def would_block_if_withdrawn
    possibly_blocks.select(&:in_nonblocking_status?)
  end

  #
  # These advisories are currently breaking the dependency rules.
  # (Using this to prevent adding a dependency rule that is already broken).
  #
  def should_have_blocked
    currently_blocks.select(&:in_nonblocking_status?)
  end

  #
  # These other advisories should have blocked this advisory, so this
  # advisory is breaking the dependency rules right now.
  # (Using this to prevent adding a dependency rule that is already broken).
  #
  def should_have_been_blocked_by
    return [] unless self.in_nonblocking_status?
    currently_blocked_by
  end
end
