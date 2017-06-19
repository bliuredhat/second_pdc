module RpmdiffTests
  extend ActiveSupport::Concern
  included do
    has_many :rpmdiff_runs
    after_update do
      return unless self.fulladvisory_changed? && self.requires_rpmdiff?
      self.rpmdiff_runs.update_all(:errata_nr => self.shortadvisory)
    end
  end


  def requires_rpmdiff?
    return false if self.text_only?
    return false unless self.has_rpms?
    self.state_machine_rule_set.test_requirements.include?('rpmdiff')
  end

  def requires_rpmdiff_review?
    requires_rpmdiff?
  end

  def rpmdiff_finished?
    return true unless requires_rpmdiff?
    # Unless text only, there should be builds and thus rpmdiff runs
    self.rpmdiff_runs.current.any? &&
      self.all_builds_have_rpmdiff_scheduled? &&
      self.rpmdiff_runs.unfinished.empty?
  end

  def all_builds_have_rpmdiff_scheduled?
    current_builds = self.build_mappings.for_rpms.pluck('DISTINCT brew_build_id')
    builds_with_rpmdiff_scheduled = self.rpmdiff_runs.current.map(&:brew_build_id).uniq
    (current_builds - builds_with_rpmdiff_scheduled).empty?
  end

  def rpmdiff_review_finished?
    return true unless requires_rpmdiff?
    return false unless rpmdiff_finished?
    # as well as no unfinished run, every waived result must be acked
    results = rpmdiff_results.where(:score => RpmdiffScore::WAIVED)
    RpmdiffWaiver.latest_for_results(results).not_acked.empty?
  end

  def rpmdiff_results
    runs = self.rpmdiff_runs.current

    # XXX workaround for performance bug http://bugs.mysql.com/bug.php?id=9021
    # MySQL fails to use the index on run_id if we use a subquery here.
    runs = runs.pluck(:run_id)

    RpmdiffResult.where(:run_id => runs)
  end

  def rpmdiff_stats
    runs = self.rpmdiff_runs.find(:all, :conditions => "obsolete = 0", :include => [:rpmdiff_score])
    stats = Hash.new(0)
    for run in runs do
      score = run.rpmdiff_score.score
      if score == RpmdiffScore::INFO
        score = RpmdiffScore::PASSED
      end
      stats[score] += 1
    end
    return stats
  end
end
