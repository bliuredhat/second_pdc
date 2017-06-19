class PdcErrataRelease < ActiveRecord::Base
  belongs_to :errata

  belongs_to :pdc_release
  belongs_to :release_version, :class_name => :PdcRelease,
             :foreign_key => :pdc_release_id


  # NOTE: see note about build_mappings in errata.rb
  has_many :pdc_errata_release_builds, { :conditions => { :current => 1 } }
  has_many :build_mappings, :class_name => :PdcErrataReleaseBuild,
           :conditions => { :current => 1 }

  has_many :brew_builds, :through => :pdc_errata_release_builds, :uniq => true
  has_many :packages, :through => :brew_builds, :uniq => true

end
