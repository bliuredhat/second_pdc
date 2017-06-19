class BrewWinArchive < BrewArchive
  def self.brew_build_type
    'win'
  end

  def self.new_from_rpc(attr)
    BrewArchive.new_from_rpc(attr, BrewWinArchive).tap do |winfile|
      winfile.relpath = attr['relpath']
    end
  end

  def file_subpath
    ['win', self.relpath].reject(&:blank?).join('/')
  end
end
