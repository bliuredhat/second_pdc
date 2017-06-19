class PdcProduct < PdcResource
  pdc_attributes :name, :short, :product_versions

  def pdc_releases
    pdc_releases = self.product_versions.map do |pdc_pv|
      PDC::V1::Release.where(product_version: pdc_pv).all
    end.flatten
    pdc_releases.uniq.sort_by(&:release_id)
  end

  def self.all_products
    PDC::V1::Product.all.map do |product_from_pdc|
      PdcProduct.get(product_from_pdc.short)
    end.sort_by(&:pdc_id)
  end
end
