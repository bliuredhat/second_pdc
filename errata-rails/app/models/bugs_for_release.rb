class BugsForRelease
  def initialize(release)
    @release = release
  end

  def eligible_bugs
    bugs = @release.bugs.eligible_bug_state(@release.valid_bug_states)
    if @release.supports_component_acl?
      rc = @release.release_components
      rc = rc.uncovered unless @release.allow_pkg_dupes?
      eligible_packages = rc.map(&:package_id)
      bugs = bugs.where(:package_id => eligible_packages)
    end
    bugs.unfiled.includes(:package => [:quality_responsibility, :qe_owner])
  end

  def ineligible_bugs
    @release.bugs.ineligible_bug_state(@release.valid_bug_states).includes(:package =>
                                                                           [:quality_responsibility, :qe_owner])
  end

  def method_missing(name, *args)
    super(name, args) unless name.to_s =~ /(.+)_by_package/
    base_name = $1
    bugs = self.send(base_name)
    bugs.each_with_object(HashList.new) { |b, h| h[b.package] << b}
  end
end
