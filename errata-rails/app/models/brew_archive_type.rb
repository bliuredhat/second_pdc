class BrewArchiveType < ActiveRecord::Base
  validates_uniqueness_of :name, :extensions
  has_many :brew_archives

  TAR_ID = 4

  def self.new_from_rpc(attr)
    id = attr['type_id']

    archive_type = BrewArchiveType.find_by_id(id)
    if archive_type.nil?
      archive_type = BrewArchiveType.new
      archive_type.id = id
      BREWLOG.info "Importing new archive type from build: #{attr.inspect}"
    end

    [:description,:extensions,:name].each do |key|
      archive_type.send("#{key}=", attr["type_#{key}"])
    end

    archive_type
  end

  def self.prepare_cached_archive_types
    BrewArchiveType.all.to_a
  end

  def self.cached_archive_types
    ThreadLocal.get(:cached_archive_types) || BrewArchiveType.all.to_a
  end
end
