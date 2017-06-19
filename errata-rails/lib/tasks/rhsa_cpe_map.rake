namespace :secalert do

  # This might be obsoleted by Secalert::CpeMapper.publish_cache. (To be confirmed).
  # Note that this version goes back to 2007 instead of 2010.
  desc "Make RHSA <> CPE mapping file for secalert consumption. Includes all cve errata >= 2007"
  task :make_cpe_map => :environment do
    elapsed = Benchmark.realtime do

      file_name = Rails.root.join('public', "rhsamapcpe.txt")
      FileWithSanityChecks::CpeMapFile.new(file_name).prepare_file { |f|
        Secalert::CpeMapper.cpe_map_since('2007-01-01', f)
      }.check_and_move

    end
    puts elapsed
  end

  desc "republish cpe_map_$YEAR rhsa cpe map cache file (default year 2010)"
  task :republish_cpe_map_cache => :environment do
    elapsed = Benchmark.realtime do
      Secalert::CpeMapper.publish_cache(ENV['YEAR'] || 2010)
    end
    puts elapsed
  end

end
