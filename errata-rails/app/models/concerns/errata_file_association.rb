module ErrataFileAssociation
  extend ActiveSupport::Concern

  included do
    # Creates an association between a file table and advisory
    #
    # Also creates an association between the advisory and variant type
    # Creates methods 'current_files' and 'variants' to wrap the type specific
    # relations, providing a uniform client interface between LegacyErrata and PdcErrata
    def self.has_many_files(association_name, table_name, variant_id_field)
      m = association_name.to_s.match(/(pdc|legacy)_.+/)
      raise ArgumentError, 'Association must start with  pdc_ or legacy_' unless m
      advisory_type = m[1]

      has_many association_name,
      :class_name => table_name.to_s.classify,
      :foreign_key => "errata_id",
      :conditions => Proc.new {
        cond = 'current = 1'
        # may be called from join association instead of Errata instance
        cond += " AND errata_id = #{id}" if defined?(id) && id
        # double sub-query to work around mysql performance issues
        %{
          #{table_name}.id IN (
            SELECT * FROM (
              SELECT MAX(id) AS id
              FROM #{table_name} WHERE #{cond}
              GROUP BY md5sum, #{variant_id_field}, arch_id, package_id, brew_build_id
            ) AS sq
          )
        }
      },
      :order => "#{variant_id_field} desc, #{table_name}.arch_id desc, brew_files.name asc",
      :include => [:arch, :variant, :brew_build, :brew_rpm, :package]

      define_method(:current_files) { self.send(association_name) }

      # The `variants` association goes through `current_files` (ErrataFiles).
      # This only works for RPM-based errata.
      #
      # The `get_variants` method may be preferable as it works for other
      # errata content types (eg, Docker).
      #
      variant_association_name = "#{advisory_type}_variants"
      has_many variant_association_name,
      :through => association_name,
      :source => :variant,
      :uniq => true

      define_method(:variants) {self.send(variant_association_name) }
    end
  end
end
