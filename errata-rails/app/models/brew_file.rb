require 'digest'

class BrewFile < ActiveRecord::Base
  belongs_to :brew_build
  belongs_to :package

  validate :unique_id_brew

  scope :nonrpm, where('brew_files.type != ?', 'BrewRpm')
  scope :tar_files, where(:brew_archive_type_id => BrewArchiveType::TAR_ID)
  scope :rpm, where(:type => 'BrewRpm')

  BREW_TOP_DIR = Settings.brew_top_dir

  attr_accessor :ftp_path
  serialize :flags, Set

  before_save do
    if self.package.nil? && !self.brew_build.nil?
      self.package = self.brew_build.package
    end
  end

  after_save do
    @file_path = nil
  end

  def file_type
    self.type
  end

  def volume_dir
    return BREW_TOP_DIR if brew_build.volume_name.blank? ||
                           brew_build.volume_name == 'DEFAULT'
    return "#{BREW_TOP_DIR}/vol/#{brew_build.volume_name}"
  end

  def file_path
    unless(@file_path)
      path = "#{volume_dir}/packages/"
      name = package_name
      ver = brew_build.version
      rel = brew_build.release

      if name =~ /!/
        rel = ver
        name =~ /(.+)!(.+)/
        name = $1
        ver = $2
      end

      path += [name, ver, rel].join('/')
      path += '/'
      path += self.file_subpath
      path += '/'
      path += self.filename

      @file_path = path
    end

    return @file_path
  end

  def md5sum
    get_checksum(Md5sum)
  end

  def sha256sum
    get_checksum(Sha256sum)
  end

  def package_name
    return package.name
  end

  def filename
    name
  end

  # Returns the filename with the subpath (if any) prepended.
  #
  # This is the smallest portion of the path which is guaranteed to be
  # unique within a build.  It's useful where filename is ambiguous
  # and file_path is too long.
  def filename_with_subpath
    [file_subpath, filename].reject(&:blank?).join('/')
  end

  def is_docker?
    false
  end

  private

  def unique_id_brew
    # id_brew must be unique within the scope of all RPMs or all
    # archives, but is not unique across both scopes together.
    other = if self.type == 'BrewRpm'
      BrewRpm
    else
      BrewFile.nonrpm
    end
    other = other.where(:id_brew => self.id_brew)
    other = other.where('id != ?', self.id) unless self.new_record?
    if other.exists?
      errors.add(:id_brew, "is already taken (by #{other.map(&:id).join(', ')})")
    end
  end

  def get_checksum(crypt_class)
    class_name = crypt_class.name

    if class_name == 'Md5sum'
      crypt_type = Digest::MD5
    elsif class_name == 'Sha256sum'
      crypt_type = Digest::SHA256
    else
      raise ArgumentError, "Invalid checksum type #{class_name}"
    end

    crypt_obj = crypt_class.brew_file_checksum(self, brew_build.sig_key)

    @file_path = nil
    # Force to recompute the checksum if it is a fake checksum
    # and if ET is mounting to brewroot directory. Do this to fix
    # all the fake checksums which had been saved to the db previously
    if can_access_file? && crypt_obj && !crypt_obj.checksum_valid?
      value = generate_checksum(crypt_type)
      crypt_obj.update_attribute(:value, value)
    elsif !crypt_obj
      value = generate_checksum(crypt_type)
      return 'FILE_MISSING' if value.nil?
      crypt_obj = crypt_class.create(:brew_file => self,
                                     :sig_key => brew_build.sig_key,
                                     :value => value)
    end
    return crypt_obj.value
  end

  def generate_checksum(crypt_type)
    if !is_production? && !can_access_file?
      # For testing purposes set a fake checksum when brewroot nfs mount is not available
      return crypt_type.hexdigest(self.file_path).sub(/^.{5}/, 'fake:')
    elsif can_access_file?
      return crypt_type.hexdigest(File.open(self.file_path,'rb').read)
    else
      logger.warn "Unable to read '#{self.file_path}' file for #{crypt_type.name.partition('::').last} calculation."
      return nil
    end
  end

  def is_production?
    Rails.env.production?
  end

  def can_access_file?
    File.exists?(self.file_path)
  end
end
