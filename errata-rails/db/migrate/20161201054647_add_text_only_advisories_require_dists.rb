class AddTextOnlyAdvisoriesRequireDists < ActiveRecord::Migration
  def up
    add_column :errata_products,
               :text_only_advisories_require_dists,
               :boolean,
               :default => true,
               :null => false

    likely_middleware_products = Product.
                                 active_products.
                                 includes(:product_versions).
                                 map(&:product_versions).
                                 flatten.
                                 select{|pv| pv.active_repos.count == 0 &&
                                        pv.active_channels.count == 0 &&
                                        pv.product.short_name.start_with?('J')}.
                                 map(&:product).uniq

    likely_middleware_products.each do |p|
      puts "Setting text_only_advisories_require_dists false for product #{p.short_name}"
      p.update_attribute(:text_only_advisories_require_dists, false)
    end
  end

  def down
    remove_column :errata_products,
                  :text_only_advisories_require_dists
  end
end
