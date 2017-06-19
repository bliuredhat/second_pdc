class BrewFileMeta < ActiveRecord::Base
  belongs_to :errata
  belongs_to :brew_file

  validates_length_of :title, :within => 5..100, :allow_nil => true
  validates_uniqueness_of :brew_file_id, :scope => :errata_id

  validate :validate_filelist_unlocked

  COMPLETE_SQL = '`brew_file_meta`.`title` IS NOT NULL AND `brew_file_meta`.`rank` IS NOT NULL'
  scope :complete, where(COMPLETE_SQL)
  scope :incomplete, where("NOT (#{COMPLETE_SQL})")

  def complete?
    valid? && title.present? && rank.present?
  end

  # Returns a BrewFileMeta for every applicable file in the advisory.
  # May include some which already exist and others which are not yet persisted.
  def self.find_or_init_for_advisory(e)
    files = e.brew_files.nonrpm.pluck(:id)
    out = BrewFileMeta.where(:errata_id => e, :brew_file_id => files).to_a
    files_with_meta = out.map(&:brew_file_id)
    files_without_meta = files - files_with_meta
    files_without_meta.each do |file|
      out << BrewFileMeta.new(:errata => e, :brew_file_id => file)
    end
    out
  end

  # Returns a BrewFileMeta for this advisory and file.
  # May exist or may be a new, unpersisted record.
  def self.find_or_init_for_advisory_and_file(errata, brew_file)
    out = BrewFileMeta.where(:errata_id => errata, :brew_file_id => brew_file)
    if out.any?
      out.first
    else
      BrewFileMeta.new(:errata => errata, :brew_file => brew_file)
    end
  end

  # Given an advisory and a list of brew file objects or IDs, sets the
  # rank on all BrewFileMeta for the advisory to establish the
  # requesting ordering on the files.
  #
  # Returns all the BrewFileMeta for the advisory (not yet saved).
  def self.set_rank_for_advisory(errata, brew_file_order)
    all_meta = BrewFileMeta.find_or_init_for_advisory(errata)
    remaining_meta = all_meta.to_set
    meta_by_file = all_meta.group_by(&:brew_file_id)

    rank = 1
    set_rank = lambda do |meta|
      meta.rank = rank
      rank += 1
    end

    # rank every explicitly mentioned file, from 1 ascending...
    brew_file_order.each do |id|
      id = id.id if id.kind_of?(BrewFile)
      (meta_by_file[id] || []).each do |meta|
        remaining_meta.delete(meta)
        set_rank.call(meta)
      end
    end

    # ...and any meta not explicitly ranked is put at the end
    remaining_meta.sort_by(&:brew_file_id).each(&set_rank)

    all_meta.sort_by(&:rank)
  end

  private

  def validate_filelist_unlocked
    if (changed? || new_record?) && errata.filelist_locked?
      errors.add(:errata, 'filelist must be unlocked to update file metadata')
    end
  end
end
