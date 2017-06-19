module Secalert
  class CpeMapper
    def initialize
      @version_rhel_maps = { }
    end

    def cpe_for_mapping(package, variant)
      cpe = cpe_for_variant variant
      "#{cpe}/#{package.name}"
    end

    def cpe_for_variant(variant)
      cpe = variant.cpe
      cpe = "cpe:/unknown" if cpe.blank?
      cpe
    end

    # FIXME: It looks like RHN and CDN can have different CPE list because the supported
    # push types can be set in the variant level and package level.
    def cpes_with_srpm_name(errata)
      cpe_list = Set.new
      errata.get_variants_by_package.each_pair do |package, variants|
        variants.each do |variant|
          cpe_list << cpe_for_mapping(package, variant)
        end
      end
      cpe_list
    end

    def cpes_without_srpm_name(errata)
      cpe_list = Set.new
      errata.get_variants.each do |variant|
        cpe_list << cpe_for_variant(variant)
      end
      cpe_list
    end

    def cpes_variants_map(errata)
      mappings = HashList.new
      errata.get_variants.each do |variant|
        mappings[cpe_for_variant(variant)] << variant.name
      end
      mappings
    end

    def cpe_text(errata, opts = {})
      separator = opts.fetch(:separator, ",")
      get_cpes = opts.fetch(:no_srpm_name, false) ? :cpes_without_srpm_name : :cpes_with_srpm_name

      if errata.text_only?
        # Use manually entered cpe_text
        cpe_text = errata.content.text_only_cpe || ""
      else
        cpe_text = self.send(get_cpes, errata).sort.join(separator)
      end
      cpe_text
    end

    def cpe_list(errata)
      cpe_list = if errata.text_only?
        # make text only cpe the same format as non text only advisory to process later
        (errata.content.text_only_cpe || "").split(",").each_with_object(HashList.new) do |cpe,h|
          h[cpe]
        end
      else
        errata.is_pdc? ? cpe_list_for_pdc_advisory(errata) : cpes_variants_map(errata)
      end
      cpe_list
    end


    # returns a HashList of cpe vs pdc_variant id
    # {
    #   "cpe:/o:redhat:enterprise_linux:7::client"      => [
    #     [0] "ceph-2.1-updates@rhel-7/MON",
    #     [1] "ceph-2.1-updates@rhel-7/OSD"
    #   ],
    #   "cpe:/o:redhat:enterprise_linux:7::computenode" => [
    #     [0] "ceph-2.1-updates@rhel-7/MON"
    #   ],
    #   "cpe:/o:redhat:enterprise_linux:7::server"      => [
    #     [0] "ceph-2.1-updates@rhel-7/OSD"
    #   ]
    # }
    #
    def cpe_list_for_pdc_advisory(pdc_advisory)
      raise "pdc_advisory isn't pdc - id: #{pdc_advisory.id}" unless pdc_advisory.is_pdc?

      # TODO: need to use get_variants when it is implemented for pdc advisory
      # TODO: consider about multi-product-mapped variants just like legacy advisory

      pdc_advisory.variants.each_with_object(HashList.new) do |variant, cpe_variants|
        variant.cpe_list.each do |cpe|
          cpe_variants[cpe] << variant.pdc_id
        end
      end
    end

    private :cpe_list_for_pdc_advisory


    def rhsa_map_cpe(errata_id, fulladvisory)
      errata = Errata.find(errata_id)
      cpe_text = self.cpe_text(errata)

      "#{short_advisory(fulladvisory)} #{errata.cve_list.join(',')} #{cpe_text}"
    end

    def short_advisory(fulladvisory)
      fulladvisory.split('-').slice(0..1).join('-')
    end

    def self.cpe_map_since_advisories(date)
      Errata.connection.select_rows("
        SELECT
          errata_main.id,
          errata_main.fulladvisory
        FROM
          errata_main
          JOIN errata_content ON errata_main.id = errata_content.errata_id
        WHERE
          errata_main.status = 'SHIPPED_LIVE'
        AND
          errata_main.issue_date >= '#{date}'
        AND
          (
            -- This has been here always
            errata_content.cve != ''
          OR
            -- This is new for bug 740819. Include text only RHSA advisories with
            -- a text_only_cpe. (Actually anything with a text_only_cpe would have
            -- a CVE I think, so this might be redundant).
            errata_content.text_only_cpe IS NOT NULL
          )
        ORDER BY
          substr(fulladvisory,6,9) DESC -- eg 2012:0006
      ")
    end

    def self.cpe_map_since(date, file_handle=nil)
      # Because rhsa_map_cpe calls some other instance methods have to do this.
      # call it as an instance method too. Refactor maybe.
      mapper = self.new

      if file_handle
        # Can use this to write the file as we go instead of returning the large list.
        cpe_map_since_advisories(date).each { |e| file_handle.puts(mapper.rhsa_map_cpe(e[0], e[1])) }
      else
        # Backwards compatible version (keep for console use or in case anything else calls this method)
        cpe_map_since_advisories(date).collect { |e| mapper.rhsa_map_cpe(e[0], e[1]) }
      end
    end

    # Publishes the cache since a given year to the public static directory
    def self.publish_cache(from_year)
      unless from_year >= 2008 && from_year <= Time.now.utc.year
        raise "Year must be between 2008 and the current year!"
      end

      # (Throws exception if sanity checks fail)
      file_name = Rails.root.join('public', "cpe_map_#{from_year}.txt")
      FileWithSanityChecks::CpeMapFile.new(file_name).prepare_file { |f|
        cpe_map_since("#{from_year}-01-01", f)
      }.check_and_move

    end
  end
end
