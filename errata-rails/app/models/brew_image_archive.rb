class BrewImageArchive < BrewArchive
  belongs_to :arch

  def self.brew_build_type
    'image'
  end

  def self.new_from_rpc(attr)
    BrewArchive.new_from_rpc(attr, BrewImageArchive).tap do |img|
      # I'm a bit fuzzy if arch is mandatory or not for images...
      if arch_name = attr['arch']
        img.arch = Arch.find_by_name!(arch_name)
      end

      # Is this a docker image?
      if attr['extra'].try(:has_key?, 'docker')
        img.flags << 'docker'
      end
    end
  end

  def file_subpath
    'images'
  end

  def file_type_display
    is_docker? ?
      "#{file_type} [Docker]" :
      file_type
  end

  def is_docker?
    flags.include?('docker')
  end

end
