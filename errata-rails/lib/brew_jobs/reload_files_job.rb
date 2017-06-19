module BrewJobs
  class ReloadFilesJob
    def initialize(mapping_id, is_pdc=false)
      @mapping_id = mapping_id
      @is_pdc = is_pdc
    end

    def perform
      mapping = BuildMappingCommon.find_by_id(@mapping_id, pdc: @is_pdc)
      unless mapping
        BREWLOG.info "mapping #{BuildMappingCommon.choose_mapping_class(pdc: @is_pdc)} #{@mapping_id} removed since enqueued - nothing to do"
        return
      end

      if (e=mapping.errata).filelist_locked?
        BREWLOG.info "filelist of advisory #{e.advisory_name} is locked - ignoring request to reload files"
        return
      end

      mapping.reload_files

      # Here product_version is a type of ProductVersion or an alias of pdc_release which type is PdcRelease
      msg = "Filelist reloaded for #{mapping.pv_or_pr.short_name}, #{mapping.brew_build.nvr}"
      mapping.errata.comments.create(:text => msg)
    end

    def self.enqueue(mapping, is_pdc=false)
      return unless mapping.current? && mapping.for_rpms?
      dj = Delayed::Job.enqueue(self.new(mapping.id, is_pdc), 5)
      BREWLOG.info "scheduled job #{dj.id} to reload files for #{mapping.id}"
    end
  end
end
