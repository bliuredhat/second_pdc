module SharedApi::Params
  def archive_type_from_param(type)
    return nil if type=='rpm'

    BrewArchiveType.find_by_name(type).tap do |archive_type|
      raise ArgumentError, "#{type} is not a known file type" unless archive_type
    end
  end

  def build_from_param(p)
    (BrewBuild.find_by_id(p) || BrewBuild.find_by_nvr(p)).tap do |build|
      raise ArgumentError, "Invalid build #{p}" unless build
    end
  end

  def product_version_from_param(p)
    (ProductVersion.find_by_name(p) || ProductVersion.find_by_id(p)).tap do |pv|
      raise ArgumentError, "Invalid product version #{p}" unless pv
    end
  end

  def pdc_release_from_param(p)
    (PdcRelease.find_by_pdc_id(p) || PdcRelease.find_by_id(p)).tap do |pr|
      raise ArgumentError, "Invalid Pdc Release #{p}" unless pr
    end
  end
end
