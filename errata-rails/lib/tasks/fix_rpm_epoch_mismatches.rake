# See Bug 888809 - ET: incorrect epoch info in OVAL
# This script fixes the build <=> subpackage rpm mismatches of all known cases
#
#    perl-5.10.1-127.el6
#    perl-5.10.1-119.el6
#    perl-5.10.1-116.el6
#    perl-5.10.1-125.el6
#    perl-5.10.1-122.el6
#    perl-5.10.1-126.el6
#    perl-5.10.1-118.el6
#    perl-5.10.1-124.el6
#    perl-5.10.1-117.el6
#    compat-gcc-295-2.95.3-85
#    perl-5.10.1-119.el6_1.1
#    compat-gcc-295-2.95.3-81
#    perl-5.10.1-121.el6
#    compat-gcc-295-2.95.3-86.el6
#    perl-5.10.1-115.el6
#
namespace :one_time_scripts do
  desc 'Fix the epoch of rpms that are known to not match their build'
  task :fix_rpm_epoch => :environment do
    mismatched_ids = [212701,
                  162915,
                  153703,
                  203891,
                  201735,
                  204601,
                  156861,
                  202341,
                  154986,
                  45228,
                  181843,
                  3221,
                  198884,
                  132565,
                  137889]

    BrewBuild.where(:id => mismatched_ids).each do |b|
      build_epoch = b.epoch.to_i
      puts "Fixing #{b.nvr} which has epoch #{build_epoch}"
      rpms = Brew.get_connection.listBuildRPMs(b.nvr)
      rpms.each do |r|
        unless r['epoch'] == build_epoch
          puts "Fixing rpm #{r['nvr']} epoch: #{build_epoch} => #{r['epoch']}"
          BrewRpm.update(r['id'], :epoch => r['epoch'])
        end
      end
      puts ""
    end
    puts "Done fixing builds"
  end
end
