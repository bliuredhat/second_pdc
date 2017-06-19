# Update flags for tar files in brew build, to indicate
# whether or not the file is a docker image.
#
namespace :brew do
  namespace :docker do

    desc "Set docker flag on tar files for a brew build"
    task :set, [:id_or_nvr] => :environment do |t, args|
      tar_files_for_build(args[:id_or_nvr]) do |file|
        file.flags << 'docker'
      end
    end

    desc "Unset docker flag on tar files for a brew build"
    task :unset, [:id_or_nvr] => :environment do |t, args|
      tar_files_for_build(args[:id_or_nvr]) do |file|
        file.flags.delete 'docker'
      end
    end

    def tar_files_for_build(id_or_nvr)
      build = BrewBuild.find_by_id_or_nvr(id_or_nvr)
      raise "Could not find build with id or NVR '#{id_or_nvr}'" unless build

      files = build.brew_files.tar_files
      raise "This build has no tar files that could be docker images" if files.none?

      puts "Updating docker flag on #{files.count} #{'file'.pluralize(files.count)}:"

      # Mark tar files as docker images
      ActiveRecord::Base.transaction do
        files.each do |tar_file|
          puts "  #{tar_file.name}"
          yield tar_file
          tar_file.save!
        end
      end

      puts "Done"
    end

  end
end
