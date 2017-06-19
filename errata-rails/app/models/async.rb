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

# Require neccessary due to an apparent rails dependency bug
# that only manifests itself in the development environment.

class Async < Release
  before_create do
    self.is_async = 1
  end

  def supports_opml?
    return false
  end
end
