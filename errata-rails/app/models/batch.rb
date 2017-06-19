class Batch < ActiveRecord::Base
  include Audited
  include CanonicalNames
  include NamedAttributes

  has_many :errata,
    :class_name => "Errata",
    :foreign_key => "batch_id",
    :conditions => "is_valid = 1 and status != 'DROPPED_NO_SHIP'"

  belongs_to :release
  belongs_to :who,
    :class_name => "User"

  validates_uniqueness_of :name
  validates :name, :presence => true
  validates :release, :presence => true
  validate :release_valid

  scope :for_release, lambda { |release| where(:release_id => release) }
  scope :active, where(:is_active => true)
  scope :released, where('released_at IS NOT NULL')
  scope :unreleased, where(:released_at => nil)
  scope :unlocked, where(:is_locked => false)

  # Order by release_date, with nulls at end
  scope :by_release_date, :order => '(release_date IS NULL), release_date, id'

  # Pre-release batches may have new errata assigned to them automatically.
  # Derived partly from the status of existing errata in the batch,
  # and includes batches that have no errata assigned to them.
  scope :pre_release, :conditions => "
    released_at IS NULL AND
    id NOT IN (
      SELECT DISTINCT COALESCE(batch_id, 0) FROM errata_main
      WHERE status IN ('IN_PUSH', 'SHIPPED_LIVE')
    )
  "

  alias_attribute :active, :is_active
  named_attributes :release

  before_validation do
    name.try(:strip!)
  end

  def blockers
    self.errata.batch_blocker
  end

  def future_release_date?
    self.release_date && self.release_date.future?
  end

  def is_released?
    self.released_at.present?
  end

  def lock
    self.is_locked = true
  end

  def unlock
    self.is_locked = false
  end

  #
  # Used to create an auto-generated batch, when there is
  # no existing batch that can be used for new errata, or
  # when errata not being released are moved from a batch.
  #
  def self.create_placeholder(*args)
    batch = create(*args)

    if batch.name.nil?
      # Name has to be unique. We don't know id of batch yet,
      # so give it a name based on current timestamp
      batch.name = Time.now.strftime('%y%m%d%H%M%S') + Time.now.usec.to_s
      batch.save!

      # Update name to something more concise
      batch.name = "Batch #{batch.id}"
    end

    batch.save!
    batch
  end

  #
  # Move any unreleased errata to next batch for this release.
  #
  def remove_prerelease_errata
    return if self.is_released?

    # Move errata in NEW_FILES, QE, REL_PREP to next batch
    pre_release_errata = self.errata.pre_release.all
    if pre_release_errata.any?
      # get next batch for release (create
      # a new batch if necessary)
      next_batch = self.release.next_batch!

      # Assign next batch to pre_release_errata
      # Could use update_all but that skips callbacks
      ActiveRecord::Base.transaction do
        pre_release_errata.each do |e|
          Rails.logger.info "Moving errata '#{e.fulladvisory}' (#{e.status}) to batch '#{next_batch.name}'"
          e.update_attributes!(:batch => next_batch)
          e.comments.create!(:text => "Advisory moved from shipping batch '#{self.name}' because it has status '#{e.status}', and hence is not ready to ship.")
        end
      end
    end

  end

  #
  # Update released_at timestamp when batch is shipped
  # (all errata are SHIPPED_LIVE or DROPPED_NO_SHIP).
  #
  def errata_shipped(errata)
    # Only mark batch as released if any of its errata are shipped
    return if self.errata.shipped_live.count == 0

    if self.errata.active.count == 0
      Rails.logger.info "Marking batch '#{self.name}' as released"
      self.update_attributes(:released_at => Time.now, :is_locked => true)
    else
      Rails.logger.info "Batch '#{self.name}' still has errata to be shipped"
    end
  end

  private

  def release_valid
    if release_id_changed? && !errata.empty?
      errors.add(:release, 'cannot be changed if batch has errata')
    end

    if release_id_changed? && !release.enable_batching?
      errors.add(:release, "'#{release.name}' does not have enable_batching set")
    end
  end

end
