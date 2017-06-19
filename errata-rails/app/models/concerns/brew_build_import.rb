module BrewBuildImport
  def import_files_from_rpc
    self.import_rpms_from_rpc
    self.import_archives_from_rpc
  end

  def import_rpms_from_rpc
    brew = Brew.get_connection
    rpms = brew.listBuildRPMs(self.id)

    rpms.each do |r|
      if BrewRpm.where(:id_brew => r['id']).exists?
        BREWLOG.debug "file #{r['id']} (#{r['nvr']}) already exists (for build #{self.nvr})"
        next
      end

      arch_name = r['arch']
      if arch_name == 'src'
        arch_name = 'SRPMS'
      end

      arch = Arch.find(:first,
                       :conditions => ["name = ?",
                                       arch_name])

      brew_rpm = BrewRpm.new
      brew_rpm.id_brew = r['id']
      brew_rpm.package = self.package
      brew_rpm.arch = arch
      brew_rpm.name = r['nvr']
      brew_rpm.epoch = r['epoch'] || 0
      self.brew_files << brew_rpm
    end
  end

  def import_archives_from_rpc
    brew = Brew.get_connection

    # we must query once per type to get type-specific metadata.
    [BrewImageArchive, BrewMavenArchive, BrewWinArchive].each do |klass|
      brew.listArchives(self.id, nil, nil, nil, klass.brew_build_type).each do |f|
        if BrewFile.nonrpm.where(:id_brew => f['id']).exists?
          BREWLOG.debug "file #{f['id']} (#{f['filename']}) already exists (for build #{self.nvr})"
          next
        end

        self.brew_files << klass.new_from_rpc(f)
      end
    end
  end

end
