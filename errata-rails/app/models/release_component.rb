class ReleaseComponent < ActiveRecord::Base
  belongs_to :release
  belongs_to :package
  belongs_to :errata

  scope :uncovered, where('errata_id is null')
  scope :for_package, lambda { |package| where(:package_id => package) }

  def self.assign_to_advisory(advisory)
    return unless advisory.release.has_approved_components?
    packages = advisory.bugs.map(&:package_id).uniq
    where(:release_id => advisory.release,
          :package_id => packages).update_all(:errata_id => advisory)
  end

  def self.unassign_from_advisory(advisory, packages)
    return unless advisory.release.has_approved_components?
    # Only remove packages if all bugs with a given pacakge have been removed
    packages.reject! {|pkg| advisory.bugs.where(:package_id => pkg).any?}
    where(:release_id => advisory.release,
          :errata_id => advisory,
          :package_id => packages).update_all(:errata_id => nil)
  end
end
