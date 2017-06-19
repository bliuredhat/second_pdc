# == Schema Information
#
# Table name: errata_groups
#
#  id                 :integer       not null, primary key
#  name               :string(2000)  not null
#  description        :string(4000)  
#  enabled            :integer       default(1), not null
#  isactive           :integer       default(1), not null
#  blocker_bugs       :string(2000)  
#  ship_date          :datetime      
#  allow_shadow       :integer       default(0), not null
#  allow_beta         :integer       default(0), not null
#  is_fasttrack       :integer       default(0), not null
#  blocker_flags      :string(200)   
#  product_version_id :integer       
#  is_async           :integer       default(0), not null
#  default_brew_tag   :string        
#  type               :string        default("QuarterlyUpdate"), not null
#  allow_blocker      :integer       default(0), not null
#  allow_exception    :integer       default(0), not null
#

class FastTrack < Release

  validate :valid_flags

  before_create do
    self.is_async = 1
  end

  def is_fasttrack?
    true
  end

  def supports_component_acl?
    false
  end

  def valid_flags
    errors.add(:blocker_flags, "fast flag is missing") unless blocker_flags.detect{|b| b == 'fast'}
    errors.add(:blocker_flags, "Need a release version flag and the fast flag") unless blocker_flags.length == 4
    errors.add(:blocker_flags, "Too many flags") if blocker_flags.length > 4
  end
end
