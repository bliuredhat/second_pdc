class PackageRestriction < ActiveRecord::Base
  include Audited
  include PushTargetsWere
  belongs_to :variant
  belongs_to :package
  belongs_to :who, :class_name => 'User'
  has_many :restricted_package_dists, :dependent => :destroy
  has_many :push_targets, :through => :restricted_package_dists, :dependent => :destroy

  validates_presence_of :package, :variant
  validates_uniqueness_of :package_id,
    :scope => :variant_id,
    :message => "Restriction already exists."
  validate :package_has_no_active_errata, :if => :has_changed?
  before_destroy :can_destroy?

  def supported_push_types
    push_targets.collect {|t| t.push_type.to_sym}.uniq
  end

  def active_errata
    # Active advisories that are shipping the package may be affected by the package
    # restriction rule, such as tps jobs, push file list etc. Better to disallow user
    # to add/update the package restriction rule if there is any active advisory
    # (exclude NEW_FILES) that is depending on the package.
    unless @affected
      @affected = []
      ErrataFile.
        select('distinct errata_id').
        includes(:errata).
        current.
        for_variant(self.variant).
        for_package(self.package).
      each do |et_file|
        errata = et_file.errata
        if errata.is_active? && errata.filelist_locked?
            @affected << errata
        end
      end
    end

    return @affected
  end

  def package_has_no_active_errata
    if self.new_record?
      package_targets = self.push_targets.map(&:name).uniq.sort
      variant_targets = self.variant.push_targets.map(&:name).uniq.sort
      # Allow to create a new restriction that has the same push targets with the variant
      return if package_targets == variant_targets
    end

    unless self.active_errata.empty?
      error_message =
        "Add/Update/Delete restriction rule for package that has active advisories"\
        " with locked filelist is not allowed. To amend the rule, please make sure all"\
        " depending active advisories are either inactive or in unlocked state."

      errors.add(:base, error_message)
      return false
    end
    return true
  end

  def can_destroy?
    raise ActiveRecord::RecordInvalid, self unless package_has_no_active_errata
    return true
  end

  def has_changed?
    return true if self.new_record?
    return true if self.package.changed?
    return true if self.push_targets_were
    return false
  end
end
