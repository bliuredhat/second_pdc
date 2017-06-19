module DistLink
  extend ActiveSupport::Concern

  included do
    validate :unique_within_product_version
  end

  def unique_within_product_version
    return unless self.product_version

    type = self.class.dist_type
    dist_id = self.send("#{type}_id")
    display_name = type.to_s.classify.constantize.display_name
    return unless dist_id

    links = self.product_version.send("#{type}_links").where("#{type}_id" => dist_id)
    unless self.new_record?
        links = links.where("#{type}_links.id != ?", self.id)
    end
    if links.any?
      errors.add(display_name, 'has already been attached to this product version.')
    end
  end
end
