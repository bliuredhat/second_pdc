class BrewArchive < BrewFile
  belongs_to :brew_archive_type
  alias_attribute :archive_type, :brew_archive_type

  def self.new_from_rpc(attr, klass=BrewArchive)
    if existing = BrewArchive.find_by_id_brew(attr['id'])
      return existing
    end

    klass.new.tap do |archive|
      archive.id_brew = attr['id']
      archive.name = attr['filename']
      archive.archive_type = BrewArchiveType.new_from_rpc(attr)
    end
  end

  def file_type
    # get cached file type first if available
    the_file_type = archive_type_cache.try(:name)
    # otherwise, look into database
    the_file_type ||= archive_type.name
  end

  def file_type_display
    file_type
  end

  def file_type_description
    # get cached file type first if available
    the_description = archive_type_cache.try(:description)
    # otherwise, look into database
    the_description ||= archive_type.description
  end

  private

  def archive_type_cache
    cached = ThreadLocal.get(:cached_archive_types) || []
    cached.find{|c| c.id == brew_archive_type_id}
  end
end
