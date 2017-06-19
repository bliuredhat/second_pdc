# == Schema Information
#
# Table name: errata_arches
#
#  id   :integer       not null, primary key
#  name :string(255)   not null
#

class Arch < ActiveRecord::Base
  NOARCH_ID = 8
  SRPM_ID   = 24

  self.table_name = "errata_arches"
  scope :active_machine_arches, where(:active => true)

  def is_srpm?
    return name == 'SRPMS'
  end

  def brew_name
    # Source rpm's arch name is different between brew and ET
    # This returns the brew style name for arch
    name == 'SRPMS' ? 'src' : name
  end

  def Arch.SRPM
    return find_by_name('SRPMS')
  end

  def self.prepare_cached_arches
    Arch.all.to_a
  end

  def self.cached_arches
    ThreadLocal.get(:cached_arches) || Arch.all.to_a
  end

  def to_s
    name
  end
end
