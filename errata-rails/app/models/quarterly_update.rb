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

class QuarterlyUpdate < Release
  validates_presence_of :ship_date
  validate(:on => :create) do
    validate_blocker_flags
  end

  def is_ystream?
    true
  end

  def bugs
    super.where("package_id in (select package_id from release_components where release_id = #{self.id})")
  end

  def has_correct_flags?(bug)
    # Prevent fast track bugs from being added to a quarterly update
    return false unless super(bug)
    return false if bug.has_flags?(['fast'])
    true
  end

  def supports_component_acl?
    true
  end

  def validate_blocker_flags
    errors.add(:blocker_flags, "Need a release version flag") if blocker_flags.length < 4
    errors.add(:blocker_flags, "Too many flags") if blocker_flags.length > 4
    return unless 4 == blocker_flags.length
    return unless Rails.env.production? || Rails.env.staging?
    release_flag_name = self.base_blocker_flags.first
    begin
      Bugzilla::Rpc.get_connection.approved_components_for release_flag_name
    rescue XMLRPC::FaultException => e
      helpful_message = case e.message
      when /No data given on release name invalid/
        "The flag '#{release_flag_name}' is valid but has no approved components defined in Bugzilla."
      when /doesn't know what flag_type_nonexistent means/
        "The flag '#{release_flag_name}' does not exist in Bugzilla."
      end
      errors.add(:blocker_flags, "- #{helpful_message} Bugzilla exception: \"#{e.message}\"")
    end
  end
end
