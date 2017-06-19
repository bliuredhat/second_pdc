class CreateVariantPushTarget < ActiveRecord::Migration
  def self.up
    begin
      create_table :variant_push_targets do |t|
        t.integer :variant_id, :null => false
        t.integer :push_target_id, :null => false
        t.integer :active_push_target_id, :null => false
        t.integer :who_id, :null => false
        t.timestamps
      end

      create_table :package_restrictions do |t|
        t.integer :package_id, :null => false
        t.integer :variant_id, :null => false
        t.integer :who_id, :null => false
        t.timestamps
      end

      create_table :restricted_package_dists do |t|
        t.integer :package_restriction_id, :null => false
        t.integer :push_target_id, :null => false
        t.integer :variant_push_target_id, :null => false
        t.timestamps
      end

      add_foreign_key(:variant_push_targets, :variant_id,            :errata_versions,     :id, :name => 'variant_push_targets_variant_id_fk')
      add_foreign_key(:variant_push_targets, :push_target_id,        :push_targets,        :id, :name => 'variant_push_targets_push_target_id_fk')
      add_foreign_key(:variant_push_targets, :active_push_target_id, :active_push_targets, :id, :name => 'variant_push_targets_active_push_target_id_fk')
      add_foreign_key(:variant_push_targets, :who_id,                :users,               :id, :name => 'variant_push_targets_who_id_fk')

      add_foreign_key(:package_restrictions, :package_id, :packages,        :id, :name => 'package_restrictions_package_id_fk')
      add_foreign_key(:package_restrictions, :variant_id, :errata_versions, :id, :name => 'package_restrictions_variant_id_fk')
      add_foreign_key(:package_restrictions, :who_id,     :users,           :id, :name => 'package_restrictions_who_id_fk')

      add_foreign_key(:restricted_package_dists, :package_restriction_id, :package_restrictions, :id, :name => 'restricted_package_dists_package_restriction_id_fk')
      add_foreign_key(:restricted_package_dists, :push_target_id,         :push_targets,         :id, :name => 'restricted_package_dists_push_target_id_fk')
      add_foreign_key(:restricted_package_dists, :variant_push_target_id, :variant_push_targets, :id, :name => 'restricted_package_dists_variant_push_target_id_fk')

      variant_supported_push_types = PushTarget.allowable_by_variant.map(&:push_type).uniq
      Variant.scoped.each do |variant|
        variant.product_version.active_push_targets.each do |active_push_target|
          target = active_push_target.push_target
          next unless variant_supported_push_types.include?(target.push_type)
          vpt = VariantPushTarget.new(
            :variant => variant,
            :push_target => target,
            :active_push_target => active_push_target,
            :who => User.current_user
          )
          # prevent the active errata validation
          vpt.save(:validate => false)
        end
      end
    rescue Exception => error
      p "Error: #{error.message}"
      down
      raise ActiveRecord::Rollback
    end
  end

  def self.down
    remove_foreign_key(:restricted_package_dists, 'restricted_package_dists_package_restriction_id_fk')
    remove_foreign_key(:restricted_package_dists, 'restricted_package_dists_push_target_id_fk')
    remove_foreign_key(:restricted_package_dists, 'restricted_package_dists_variant_push_target_id_fk')

    remove_foreign_key(:package_restrictions, 'package_restrictions_package_id_fk')
    remove_foreign_key(:package_restrictions, 'package_restrictions_variant_id_fk')
    remove_foreign_key(:package_restrictions, 'package_restrictions_who_id_fk')

    remove_foreign_key(:variant_push_targets, 'variant_push_targets_variant_id_fk')
    remove_foreign_key(:variant_push_targets, 'variant_push_targets_push_target_id_fk')
    remove_foreign_key(:variant_push_targets, 'variant_push_targets_active_push_target_id_fk')
    remove_foreign_key(:variant_push_targets, 'variant_push_targets_who_id_fk')

    drop_table :restricted_package_dists
    drop_table :package_restrictions
    drop_table :variant_push_targets
  end
end
