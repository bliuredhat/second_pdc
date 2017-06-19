class BrewMavenArchive < BrewArchive
  validates_presence_of :maven_groupId
  validates_presence_of :maven_artifactId

  def self.brew_build_type
    'maven'
  end

  def self.new_from_rpc(attr)
    BrewArchive.new_from_rpc(attr, BrewMavenArchive).tap do |artifact|
      artifact.maven_groupId = attr['group_id']
      artifact.maven_artifactId = attr['artifact_id']
    end
  end

  def file_subpath
    [
      'maven',
      self.maven_groupId.gsub('.', '/'),
      self.maven_artifactId,
      self.brew_build.version
    ].join('/')
  end
end
