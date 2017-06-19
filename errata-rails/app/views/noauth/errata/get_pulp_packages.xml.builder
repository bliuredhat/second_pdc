xml.pulp_packages(:errata => @errata.id) do
  @repo_files.each_pair do |repo, files|
    xml.repo(:idname => repo) do
      files.each do |f|
        xml.file f
      end
    end
  end
end
