require 'ostruct'

module BrewBuildRelations
  class Relation < OpenStruct
    def satisfied?
      self.satisfied || false
    end

    def self.enabled?
      true
    end
  end

  # Base class for ppc64le and aarch64 build pair relation classes
  class NonIntegratedArchBuildPair < Relation
    def summary
      "#{slug} counterpart of #{self.nvr}"
    end

    # Explanation text for this relation, in the context of the
    # specific builds.
    def explanation
      <<-"eos"
This build has been added to the builds list because it is
the #{slug} build corresponding to #{self.nvr}.
eos
    end

    # A general explanation of this relation, outside of the context
    # of this specific build (and hence suitable for display in an
    # area shared by many relations).
    def general_explanation
      # The .html_safe is a bit lame, but we need to be able to include
      # HTML in this setting.
      Settings.send("#{slug}_build_pair_explanation").html_safe
    end

    # TODO Support PDC
    def self.get_related(args)
      out = []
      return out unless self.enabled?
      errata = args[:errata] || raise('missing :errata')
      return out if errata.is_pdc?

      pv_map = self.product_version_map
      source_pv = args[:product_version] || raise('missing :product_version')
      nvr = args[:nvr] || raise('missing :nvr')
      dest_pv_name = self.product_version_map[source_pv.name]

      return out unless dest_pv_name

      nvr =~ /^(.+)-([^-]+)-([^-]+)$/
      (name, version, release) = [$1, $2, $3]
      return out unless release

      other_release = self.get_other_release(release)
      return out if other_release == release

      dest_pv = ProductVersion.find_by_name(dest_pv_name)
      return out unless errata.available_product_versions.include?(dest_pv)

      out << self.new.tap do |rel|
        rel.nvr = nvr
        rel.product_version = source_pv
        rel.related_nvr = "#{name}-#{version}-#{other_release}"
        rel.related_product_version = dest_pv
        rel.satisfied = errata.errata_brew_mappings.
          joins(:brew_build).
          where(:product_version_id => dest_pv.id,
            :brew_builds => {:nvr => rel.related_nvr}).
          any?
      end

      return out
    end

    # TODO Support PDC
    def self.for_errata(errata)
      return [] unless self.enabled? && errata.is_legacy?
      errata.errata_brew_mappings.
        includes(:brew_build, :product_version).
        joins(:product_version).
        for_rpms.
        where(:product_versions => {:name => self.product_version_map.keys}).
        map{|m|
          {:errata => errata, :product_version => m.product_version,
           :nvr => m.brew_build.nvr}
        }.
        uniq.map{|args| self.get_related(args)}.flatten
    end
  end

  # Non-ppc64le -> ppc64le pairs; bug 1188483.
  class Ppc64LeCounterpart < NonIntegratedArchBuildPair
    def slug
      'ppc64le'
    end

    private

    def self.get_other_release(release)
      release.gsub(/\.el7/, '.ael7b')
    end

    def self.product_version_map
      Settings.ppc64le_product_version_map || {}
    end
  end

  # Non-aarch64 -> aarch64 pairs; bug 1210566
  class Aarch64Counterpart < NonIntegratedArchBuildPair
    def slug
      'aarch64'
    end

    private

    def self.enabled?
      Settings.aarch64_build_pair_enabled
    end

    def self.get_other_release(release)
      release.gsub(/\.el7/, '.aa7a')
    end

    def self.product_version_map
      Settings.aarch64_product_version_map || {}
    end
  end

  def self.get_related(args={})
    NonIntegratedArchBuildPair.descendants.map{|klass|
      klass.get_related(args)
    }.flatten
  end

  def self.for_errata(errata)
    NonIntegratedArchBuildPair.descendants.map{|klass|
      klass.for_errata(errata)
    }.flatten
  end
end
