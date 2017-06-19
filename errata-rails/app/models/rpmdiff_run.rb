class RpmdiffRun < ActiveRecord::Base
  self.table_name = "rpmdiff_runs"
  self.primary_key = "run_id"

  belongs_to :rpmdiff_score,
    :foreign_key => "overall_score"
  belongs_to :errata
  belongs_to :errata_file
  belongs_to :brew_build
  belongs_to :brew_rpm
  has_many :rpmdiff_results,
     :foreign_key => 'run_id',
     :include => [:rpmdiff_test,:rpmdiff_score]
  belongs_to :package
  belongs_to :errata_brew_mapping
  belongs_to :pdc_errata_release_build
  belongs_to :last_good_run,
  :class_name => 'RpmdiffRun'

  scope :unfinished, -> {where(obsolete: false,
                               overall_score: [RpmdiffScore::NEEDS_INSPECTION,
                                               RpmdiffScore::FAILED,
                                               RpmdiffScore::NOT_COMPLETED])}


  scope :current, -> {where(:obsolete => false).where('overall_score != ?', RpmdiffScore::DUPLICATE)}

  validates_presence_of :errata,
                        :new_version,
                        :obsolete,
                        :old_version,
                        :overall_score,
                        :package,
                        :package_name,
                        :person,
                        :run_date,
                        :variant

  validate :brew_build_has_srpm
  validate :consistent_pdc_state
  validate :variant_has_rhel_variant

  before_validation(on: :create) do
    self.prepare
  end

  def is_pdc?
    pdc_errata_release_build_id.present?
  end

  def build_mapping
    @_build_mapping ||= begin
      is_pdc? ? pdc_errata_release_build : errata_brew_mapping
    end
  end

  def prepare
    return if @prepared

    self.errata = build_mapping.errata
    self.brew_build = build_mapping.brew_build
    self.brew_rpm = brew_build.srpm
    self.errata_nr = errata.shortadvisory
    self.package_name = brew_build.package.name
    # We may be called on a build with no SRPM.
    # If so, don't crash here; crash nicely in a validation elsewhere.
    self.package_path = brew_rpm.try(:file_path)
    self.package = brew_build.package
    self.overall_score = RpmdiffScore::QUEUED_FOR_TEST

    set_old_version
    self.new_version = "#{brew_build.version}-#{brew_build.release}"
    self.run_date = Time.now
    self.person ||= MAIL['default_qa_user']

    @prepared = true
  end

  def invalidate!
    self.obsolete = 1
    self.save
  end

  def current?
    !(self.obsolete? || self.duplicate?)
  end

  def duplicate?
    'Duplicate' == self.rpmdiff_score.description
  end

  def reschedule(who = MAIL['default_qa_user'])
    self.invalidate!

    if is_pdc?
      run = RpmdiffRun.create!(:pdc_errata_release_build => build_mapping,
                               :variant => variant,
                               :person => who)
    else
      map = build_mapping
      # Workaround for some old rpmdiff records are missing an errata_brew_mapping_id
      map ||= ErrataBrewMapping.where(errata_id: errata, brew_build_id: brew_build).first
      run = RpmdiffRun.create!(:errata_brew_mapping => map,
                               :variant => variant,
                               :person => who)
    end
    run
  end

  def set_old_version
    # Ensure the prior good run does not have the same brew build,
    # in the case of a rescheduling
    prior = find_prior_rpmdiff_run
    if prior.present?
      self.last_good_run = prior
      self.old_version = prior.new_version
      return
    end

    if is_pdc?
      old_pkg = PdcReleasedPackage.latest_for_build_mapping(build_mapping)
    else
      old_pkg = ReleasedPackage.latest_for_build_mapping(build_mapping)
    end

    if old_pkg.present?
      self.old_version = "#{old_pkg.brew_build.version}-#{old_pkg.brew_build.release}"
    else
      self.old_version = 'NEW_PACKAGE'
    end
  end

  def find_prior_rpmdiff_run
    prior_run_conditions = {
      :rpmdiff_runs => {
        :errata_id => self.errata,
        :package_id => self.package,
        :overall_score => [
          RpmdiffScore::PASSED,
          RpmdiffScore::INFO,
          RpmdiffScore::WAIVED,
        ],
        :variant => self.variant,
        :obsolete => 0,
      }
    }

    if is_pdc?
      prior_run_conditions[:pdc_errata_release_builds] = {
        :pdc_errata_release_id => self.pdc_errata_release_build.pdc_errata_release_id,
      }
      prior = RpmdiffRun.joins(:pdc_errata_release_build)\
        .where(prior_run_conditions)\
        .where('rpmdiff_runs.brew_build_id < ?', self.brew_build.id)\
        .order('run_id desc').first
    else
      prior_run_conditions[:errata_brew_mappings] = {
        :product_version_id => self.errata_brew_mapping.product_version_id,
      }
      prior = RpmdiffRun.joins(:errata_brew_mapping)\
        .where(prior_run_conditions)\
        .where('rpmdiff_runs.brew_build_id < ?', self.brew_build.id)\
        .order('run_id desc').first
    end
    prior
  end

  def to_s
    "Errata #{errata.shortadvisory} Build #{brew_build.nvr} Variant #{variant} SRPM #{brew_rpm.try(:file_path)}"
  end

  def self.invalidate_all_runs(errata)
    invalidate(errata.rpmdiff_runs)
  end

  # Returns all rpmdiff runs for an advisory which can be directly or indirectly
  # reached from the advisory's current brew builds and baseline.
  #
  # A run is directly reachable if its brew build is mapped to the advisory.
  #
  # A run is indirectly reachable if it is the most recent run with a
  # new_version and package equal to the old_version and package of any reachable
  # run.
  def self.reachable_runs(errata)
    current_runs = errata.rpmdiff_runs.current.order('run_id DESC')
    root_runs = current_runs.where('brew_build_id in (?)', errata.brew_builds)
    out = []

    root_runs.group_by(&:package).each do |pkg,runs|
      until runs.empty?
        new_runs = []
        runs.each do |r|
          out << r
          new_run = current_runs.select{|cr| cr.package == pkg && cr.new_version == r.old_version}.first
          new_runs << new_run unless new_run.nil?
        end
        runs = new_runs - out
      end
    end

    out
  end

  def self.invalidate_obsolete_runs(errata)
    errata.brew_builds.reload

    to_invalidate = errata.rpmdiff_runs.current
    unless (r=reachable_runs(errata)).empty?
      to_invalidate = to_invalidate.where('run_id not in (?)', r)
    end

    invalidate(to_invalidate)
  end

  def self.schedule_runs(errata, who = MAIL['default_qa_user'])
    all_errors = []
    errata.reload
    transaction do
      all_errors.concat(schedule_runs_for_current_builds(errata, who))
      invalidate_obsolete_runs errata
    end
    errata.rpmdiff_runs.unfinished.reload
    return all_errors
  end

  private

  def consistent_pdc_state
    if is_pdc?
      errors.add(:errata, "Advisory must be PDC") unless errata.is_pdc?
      errors.add(:errata_brew_mapping,'Must be absent for a PDC Advisory') if errata_brew_mapping.present?
      errors.add(:pdc_errata_release_build,'Must be present for a PDC Advisory') if pdc_errata_release_build.blank?
    else
      errors.add(:errata, "Advisory must not be PDC") if errata.is_pdc?
      errors.add(:errata_brew_mapping,'Must be present for a non-PDC advisory') if errata_brew_mapping.blank?
      errors.add(:pdc_errata_release_build,'Must be absent for a non-PDC Advisory') if pdc_errata_release_build.present?
    end
  end

  def brew_build_has_srpm
    # Checking if build_mapping(errata_brew_mapping/pdc_errata_release_build)
    # is nil or not might not be the best approach here since it never
    # happen again since Dec. 2009. But until it's patched, it's required.
    # To following up, please see also bug: 1275849
    if build_mapping.present?
      brew_build = build_mapping.brew_build
      errata_id = build_mapping.errata.id

      unless brew_build.srpm
        logger.error "Not scheduling RPMDiff run for errata #{errata_id} Build #{brew_build.nvr} - missing SRPM"
        errors.add(:base, "Can't schedule RPMDiff run for '#{brew_build.nvr}' because this brew build doesn't contain SRPM.")
      end
    else
      logger.error "Errata Brew mapping for RPMDiff run #{run_id} is missing."
      errors.add(:base, "Errata Brew mapping for RPMDiff run #{run_id} is missing.")
    end
  end

  def variant_has_rhel_variant
    # For PDC advisory, we assume the data has variant
    return if is_pdc? || self.variant.present?
    release_name = errata_brew_mapping.product_version.rhel_release.name
    logger.error "Not scheduling RMPDiff run. No rhel variant for #{errata_brew_mapping.inspect}!!"
    errors.add(:base, "Can't schedule RPMDiff run because there is no rhel variant for #{release_name} release.")
  end


  private

  # Invalidates a set of rpmdiff runs
  def self.invalidate(invalid_runs)
    invalid_runs.each do |run|
      run.invalidate!
    end
  end

  def self.schedule_runs_for_current_builds(errata, who)
    mappings_to_schedule = errata.build_mappings.for_rpms.group_by(&:brew_build)

    # A build may be referenced in multiple mappings.
    # In that case, we only want to schedule one run for the build.
    #
    # To do this, we first prepare all the runs which might be scheduled,
    # then have a look at them to decide which one is best.
    run_candidates = mappings_to_schedule.map do |brew_build,mappings|
      runs = mappings.map{|m|
        if errata.is_pdc?
          RpmdiffRun.new(
            :pdc_errata_release_build => m,
            :variant => variant_for_scheduling(m),
            :person => who).tap(&:prepare)
        else
          RpmdiffRun.new(
            :errata_brew_mapping => m,
            :variant => variant_for_scheduling(m).try(:name),
            :person => who).tap(&:prepare)
        end
      }
      [brew_build, runs]
    end

    result = HashList.new
    run_candidates.each{|brew_build,runs|
      this_result = schedule_run_from_candidates(errata, brew_build, runs)
      result[:errors].concat(this_result[:errors])
      result[:replaced].concat(this_result[:replaced])
    }

    add_runs_replaced_comment(errata, result[:replaced])

    result[:errors]
  end

  # Given an ErrataBrewMapping, returns the variant which shall be
  # used for scheduling an rpmdiff run.
  # Given a PdcErrataReleaseBuild, return the same format of variant
  # (like it for ErrataBrewMapping) from tweaking a pdc release's variant
  def self.variant_for_scheduling(m)
    is_pdc = (m.class.name == 'PdcErrataReleaseBuild')
    if is_pdc
      match = m.pdc_release.base_product.match(/(?<name>^.*)-(?<version>[^-]+)$/)
      match['version'].strip + m.pdc_release.variants.first.name
    else
      # Make sure any RHEL variant belonging to _this_ product version
      # takes precedence.
      #
      # This is important because one advisory may have two product
      # versions for the same RHEL release but with incompatible RPMs.
      # RHEL-7.1.Z (non-ppc64le) and RHEL-LE-7.1.Z (ppc64le) is an
      # example of this.
      #
      # RPMDiff should schedule separately for those two product
      # versions, which means we should pick separate variants.
      #
      # It seems odd that we pick one variant out of the available list
      # of RHEL variants when doing the scheduling, but it's been this
      # way since originally implemented in 2008.  Evidence suggests
      # rpmdiff may be using only a part of the variant name to decide
      # the RHEL release used for testing (e.g. a variant name beginning
      # with "7" implies testing for RHEL 7).
      m.rhel_variants.sort_by{|v|
        [v.product_version_id == m.product_version_id ? 0 : 1, v.id]
      }.first
    end
  end

  # Given a list of possible rpmdiff runs for a build, returns the
  # runs ordered descending by most preferable one to schedule.
  def self.in_order_for_scheduling(runs)
    runs.sort{|a,b|
      av = a.old_version
      bv = b.old_version

      if av == bv
        # Baselines are the same.
        # In that case:
        # - prefer an existing run, so we don't unnecessarily reschedule things
        # - otherwise use the variant to at least make the result stable
        if a.new_record? == b.new_record?
          next (a.variant||'') <=> (b.variant||'')
        elsif a.new_record?
          next 1
        elsif b.new_record?
          next -1
        end
      end

      if av == 'NEW_PACKAGE'
        next 1
      elsif bv == 'NEW_PACKAGE'
        next -1
      end

      # old versions are both set to some version and release.
      # Compare by rpmvercmp algorithm to decide which is newer.
      (aver,arel) = av.split(/-/, 2)
      (bver,brel) = bv.split(/-/, 2)

      -RpmVersionCompare.rpm_version_compare_evr(
        0, aver, arel,
        0, bver, brel)
    }
  end

  def self.schedule_run_from_candidates(errata, brew_build, candidates)
    out = HashList.new

    # We're not only considering scheduling runs for uncovered
    # builds but also whether we could create a new run more
    # suitable than an existing run.
    existing_run = RpmdiffRun.where(
      'errata_id = ? and brew_build_id = ? and obsolete = 0',
      errata, brew_build).first

    if existing_run
      candidates << existing_run
    end

    candidates = in_order_for_scheduling(candidates)

    # Try the runs in order and break once any of them could be saved.
    # (This will generate error messages for runs which should have been
    # scheduled but turned out not to be valid.)
    saved_run = nil
    candidates.each do |run|
      logger.info "Creating RPMDiff run for #{errata.id} build #{brew_build.nvr} variant #{run.variant}" if run.new_record?
      begin
        run.save! if run.new_record?
        saved_run = run
        break
      rescue ActiveRecord::RecordInvalid => error
        logger.warn "Could not create RPMDiff run: #{error.message}"
        out[:errors] << error.message
      end
    end

    # If we chose a new run other than the one which already existed,
    # that one becomes obsolete.
    if existing_run && existing_run != saved_run
      existing_run.invalidate!
      out[:replaced] << [existing_run, saved_run]
    end

    out
  end

  # In some cases, scheduling runs for current builds may replace
  # earlier scheduled runs, if the scheduler thinks it can make a
  # better decision now (e.g. baselines changed).
  #
  # In that case, we post a comment explaining what happened,
  # generated by this method.
  def self.add_runs_replaced_comment(errata, replaced)
    text_for_run = lambda do |run|
      "run #{run.id} [#{run.package_name} #{run.old_version} => #{run.new_version}]"
    end

    text = replaced.map do |old,new|
      [text_for_run.call(old),
       ' was replaced by ',
       text_for_run.call(new)].join.capitalize
    end

    return if text.blank?

    runs_have = replaced.length > 1 ? 'runs have' : 'run has'

    full_text = <<-"eos"
Due to a change in baseline or variant, the following RPMDiff #{runs_have} been replaced:

  #{text.join("\n  ")}
eos

    errata.comments << RpmdiffComment.new(
      :who => User.default_qa_user,
      :text => full_text)
  end
end
