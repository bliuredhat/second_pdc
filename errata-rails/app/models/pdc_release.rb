class PdcRelease < PdcResource

  # Here product_version is PDC's product version, not Errata's
  pdc_attributes :name, :variants, :brew, :active, :base_product, :product_version

  # Define alias for readability and convenience since this one should be a boolean
  alias_method :active?, :active

  has_and_belongs_to_many :releases
  has_many :pdc_errata_releases
  has_many :errata, :through => :pdc_errata_releases

  def valid_tags
    brew.try(:allowed_tags) || []
  end

  def short_name
    self.pdc_id
  end

  def verbose_name
    self.name
  end

  def allow_buildroot_push
    # Ignore push to build roots for the CEPH MVP currently.
    # Will discuss this later if we can get this through PDC api.
    false
  end
  alias_method :allow_buildroot_push?, :allow_buildroot_push

  def push_targets
    PushTarget.where(name: push_target_names)
  end

  def channels
    @_channels ||= PDC::V1::ContentDeliveryRepo.where(release_id: pdc_id, service: 'rhn').all!
  end

  def cdn_repos
    # ET calls them "cdn repos" since CDN content is distributed using Pulp
    @_cdn_repos ||= PDC::V1::ContentDeliveryRepo.where(release_id: pdc_id, service: 'pulp').all!
  end
  alias_method :active_cdn_repos, :cdn_repos

  # Convert PDC objects to local ActiveRecord objects
  def pdc_variants
    variants.all!.map{ |v| PdcVariant.get_by_release_and_variant(pdc_id, v.uid) }
  end

  def display_name
    'PDC Release'
  end

  def rhel_release
    # In PDC, if a release has base product, the base product represents
    # the operating system on which the release is supposed to run on,
    # let's assume it is the rhel_release in Errata.
    # If a release doesn't have base product, then itself is the operating
    # system like rhel6/rhel7, etc. Then let's assume the product version
    # is the rhel_release in Errata.
    # There is some exception, for example pdc release pegas-7.4, looks like
    # it is not in the rhel streamline, let's leave it out of scope currently.
    #
    base_product || product_version
  end

  def rhel_release_number
    m = rhel_release.match(/(?<name>^.*)-(?<number>[^-]+)$/)
    m['number'].to_i
  end

  def is_at_least_rhel5?
     rhel_release_number >= 5
  end

  def self.active_releases
    begin
      inactive_release_ids = PDC::V1::Release.where(active: false, page_size: -1).all!.map(&:release_id)
      PdcRelease.where('pdc_id NOT IN (?)', inactive_release_ids).order('pdc_id')
    rescue PDC::Error => e
      []
    end
  end

  private

  def push_target_names
    # Hardcode temparily, consider to get it through PDC's API in the future
    # Need to discuss with RCM guys how to save push targets using PDC's release API.
    # The jira issue is https://projects.engineering.redhat.com/browse/PDC-1895
    Settings.pdc_push_target_names
  end

end
