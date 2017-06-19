class PdcVariant < PdcResource

  # TODO: delete this concern when PDC adds the support for fetching cpe list
  include PdcLocalCpeList

  pdc_class_name :ReleaseVariant

  # Excluding :uid here since we derive it from the pdc_id
  pdc_attributes :release, :variants, :name, :arches, :type

  def self.get_by_release_and_variant(pdc_release_pdc_id, variant_uid)
    get("#{pdc_release_pdc_id}/#{variant_uid}")
  end

  # We can get some fields directly from the pdc_id field.
  # This avoids needless PDC requests, so let's do it.
  def uid
    pdc_id.split('/').last
  end

  def pdc_release_pdc_id
    pdc_id.split('/').first
  end

  def pdc_record
    @_pdc_record ||= self.class.pdc_class.where(:release => pdc_release_pdc_id, :uid => uid).first
  end

  def channels
    @_channels ||= PDC::V1::ContentDeliveryRepo.where(release_id: release.release_id, service: 'rhn', variant_uid: uid).all!
  end

  def cdn_repos(extra_params={})
    # ET calls them "cdn repos" since CDN content is distributed using Pulp
    # (extra_params is so we can also filter by content_category if needed)
    @_cdn_repos ||= PDC::V1::ContentDeliveryRepo.where({release_id: release.release_id, service: 'pulp', variant_uid: uid}.merge(extra_params)).all!
  end

  def pdc_release
    PdcRelease.get(pdc_release_pdc_id)
  end

  def release_version
    pdc_release
  end

  # Currently there is no per-variant push target configuration for PDC advisories
  # so let's just return the list from the pdc release. Returns a list of syms to
  # match the equivalent method in legacy Variant model.
  def supported_push_types
    pdc_release.push_targets.map(&:target_name)
  end

  def verbose_name
    @_verbose_name ||= "#{pdc_release.verbose_name} #{name}"
  end

  def short_name
    pdc_id
  end

  # For compatibility with Variant records
  alias_method :description, :verbose_name

  #
  # We now only call this for SRPMS and with content_category: 'source'.
  # Note that the caller actually doesn't specify an arch even though technially
  # it should. It doesn't matter though since SRPMS dir should be identical for
  # all the different arches anyway.
  # TODO: Refactor this and make it more understandable.
  #
  def ftp_path_repos(extra_params={})
    # These have no equivalent in legacy ET data
    # For legacy advisories the path is calculated by Push::Ftp.get_ftp_dir, see lib/push/ftp.rb)
    # (extra_params is so we can filter by arch and by content_category)

    # Rather than make a separate PDC request for each arch and content_category, let's fetch all of them
    @_all_ftp_path_repos ||= PDC::V1::ContentDeliveryRepo.where(release_id: release.release_id, content_format: 'rpm', service: 'ftp.redhat.com', variant_uid: uid).all!

    # Now we'll filter based on the extra_params if there were any
    result = @_all_ftp_path_repos
    extra_params.each_pair do |key, value|
      # (We may get symbols hence the comparison uses to_s)
      result = result.select{ |ftp_path_repo| ftp_path_repo.send(key).to_s == value.to_s }
    end
    result
  end
end
