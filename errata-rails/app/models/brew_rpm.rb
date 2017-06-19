# == Schema Information
#
# Table name: brew_rpms
#
#  id              :integer       not null, primary key
#  brew_build_id   :integer       not null
#  package_id      :integer       not null
#  arch_id         :integer       not null
#  has_cached_sigs :integer       default(0), not null
#  is_signed       :integer       default(0), not null
#  name            :string
#  has_brew_sigs   :integer       default(0), not null
#

class BrewRpm < BrewFile
  include RpmVersionCompare

  belongs_to :arch

  after_save do
    @file_path = nil
  end

  def arch_with_cache
    # get cached arches first if exists
    arches   = ThreadLocal.get(:cached_arches) || []
    rpm_arch = arches.find{|a| a.id == self.arch_id}
    # otherwise, look into database
    rpm_arch ||= self.arch_without_cache
  end
  alias_method_chain :arch, :cache

  def file_type
    'rpm'
  end

  def file_type_display
    'RPM'
  end

  def file_type_description
    'Package file'
  end

  def file_subpath
    path = ''

    if self.is_signed?
      path += 'data/signed/'
      path += brew_build.sig_key.keyid
      path += '/'
    end

    arch_name = arch.name
    arch_name = 'src' if arch_name == 'SRPMS'
    path += arch_name

    path
  end

  def mark_as_signed
    self.is_signed = 1
    self.has_brew_sigs = 1
    @file_path = nil
  end

  def unsign!
    self.is_signed = 0
    self.has_brew_sigs = 0
    save!

    [Md5sum, Sha256sum].each do |sum|
      sum.delete_all(:brew_file_id => self)
    end
  end

  def is_debuginfo?
    index = name =~ /debuginfo/
    return index != nil
  end

  def is_srpm?
    return self.arch_id == Arch::SRPM_ID
  end

  def is_noarch?
    return self.arch_id == Arch::NOARCH_ID
  end

  # Used to find ftp path for RHN pushes of PDC advisories
  def pdc_content_category
    if is_srpm?
      'source'
    elsif is_debuginfo?
      'debug'
    else
      'binary'
    end
  end

  def name_version_rel
    if name =~ /^(.*)-([^-]+)-([^-]+)$/
      [$1,$2,$3]
    end
  end

  def name_nonvr
    if name =~ /^(.*)-([^-]+)-([^-]+)$/
      return $1
    end
  end

  def release
    name_version_rel.last
  end

  def rpm_name
    arch_name = arch.name
    arch_name = 'src' if arch_name == 'SRPMS'
    return name + '.' + arch_name + '.rpm'
  end
  alias_method :filename, :rpm_name

  def version
    name_version_rel[1]
  end
end
