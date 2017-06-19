namespace :one_time_scripts do
  def get_channel_from_advisory_data(job)
    if job.errata.product.is_rhel?
      links = job.variant.product_version.channel_links.joins(:channel).where(:channels => {:arch_id => job.arch_id},
                                                                              :variant_id => job.version_id)
    else
      acceptable_versions = ErrataFile.where(:current => true,
                                             :errata_id => job.errata_id).select('version_id').group(:version_id).map(&:version_id)
      links = ChannelLink.joins(:channel).includes(:channel).where(:variant_id =>
                                                                       acceptable_versions,
                                                                   :channels => {:arch_id => job.arch_id})
    end
    return nil if links.empty?

    link = links.select { |l| l.channel.class == PrimaryChannel && l.variant.rhel_variant_id == job.version_id }.first
    link ||= links.select { |l| l.variant.rhel_variant_id == job.version_id }.first
    link ||= links.first
    link.channel
  end

  desc "Sets channels for active tps jobs without channels"
  task :set_tps_channels => :environment do
    jobs = TpsJob.where(:errata_id => Errata.active).where('channel_id is null')
    jobs = jobs.includes(:variant, :arch, :errata => [:product])
    puts "Setting channels for #{jobs.count} tps jobs"
    jobs.each do |j|
      channel = get_channel_from_advisory_data(j)
      j.channel = channel
      j.save(:validate => false)
    end
    jobs = TpsJob.where(:job_id => jobs).where('channel_id is null')
    puts "Finished. Still #{jobs.count} active tps jobs without channels."
    jobs.each {|j| puts [j.errata.advisory_name,
                         j.errata.product.short_name,
                         j.job_id,
                         j.variant.name,
                         j.arch.name].join(" ")}
  end
end
