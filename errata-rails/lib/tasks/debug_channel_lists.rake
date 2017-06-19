#
# Looking at RhnPush.rpm_channel_map in relation to this ticket [1]
# and finding it quite hard to decipher. So let's write some code to
# help me understand/test/debug it.
#
# (Later this kind of thing should be exposed to users via the web UI,
# see the package troubleshooter bug 1040227).
#
# [1] https://engineering.redhat.com/rt/Ticket/Display.html?id=279354
#
namespace :debug do
  namespace :channel_lists do

    desc "Show channel lists for a particular errata"
    task :show_lists => :environment do
      errata = FromEnvId.get_errata(:quiet=>true)
      format = "%-20s | %-30s | %-20s"
      puts format % %w[Advisory Build ProductVersion]
      puts '-' * 76

      errata.errata_brew_mappings.each do |ebm|
        puts format % [errata.fulladvisory, ebm.brew_build.nvr, ebm.product_version.name]
        listing = []

        puts "\n=== Looking at errata_brew_mapping.build_product_listing_iterator for the above mapping ==="
        ebm.build_product_listing_iterator do |rpm, variant, brew_build, arch_list|
          listing << [ebm.product_version.name, variant.name, rpm.rpm_name, arch_list.map(&:name).sort.join(", ")]
        end
        listing.sort_by{ |r| r[0..3] }.each { |r| puts "* %-20s %-16s %-40s %-20s" % r}
      end

      puts "\n=== Looking at RhnPush.rpm_channel_map(errata) ==="
      listing = []
      RhnPush.rpm_channel_map(errata, :ignore_srpm_exclusion => true) do |brew_build, rpm, variant, arch, channels, mapped_channels|
        listing << [brew_build.nvr, variant.name, arch.name, (channels+mapped_channels).map(&:name).join(", ")]
      end
      listing.sort_by{ |r| r[0..3] }.each { |r| puts "* %-20s %-16s %-10s %s" % r}

    end

  end
end
