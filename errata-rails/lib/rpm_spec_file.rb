# :simplecov_exclude: :nodoc
class RpmSpecFile
  attr_reader :spec_file
  attr_reader :version
  attr_reader :release
  attr_reader :changelog
  attr_reader :previous_tag
  attr_reader :filename

  def self.current
    @spec ||= RpmSpecFile.new(spec_file)
  end

  def self.spec_file
    ENV['SPEC_FILE'] || 'errata-rails.spec'
  end

  def initialize(spec_file)
    @filename = spec_file
    parse
  end

  def version_release
    "#{version}-#{release}"
  end

  private

  def parse
    @version = value_of 'Version'
    @release = value_of 'Release'

    changelog, @previous_tag = contents.match(/
      \n%changelog\n       # Start from the %changelog line
      (\*.*?)              # Capture line (starting with '*') then anything (non-greedy) until...
      \n\*\s               # we hit the next line starting with a '*'
      .*?>\s([\d\.\-]+)\n  # which has a version number at the end
    /mx)[1, 2]             # m for multiline, x to annotate, [1,2] to get the captures
    @changelog = changelog.lines.drop(1)
  end

  def value_of(key)
    contents.split("\n").
      grep(/^(#{key}):/).first.chomp.
      split(/\s/).last.sub('%{?dist}', '')
  end

  def contents
    @contents ||= File.read(@filename)
  end
end
