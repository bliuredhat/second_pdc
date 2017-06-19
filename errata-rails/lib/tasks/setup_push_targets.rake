namespace :one_time_scripts do

  # Run once, only after migration 20130206214118_create_push_targets
  desc "Sets up initial push targets after conversion"
  task :setup_initial_push_targets => :environment do
    raise "Push targets already exist!" if PushTarget.any?
    targets = {}
    targets[:rhn_live] = PushTarget.create!(:name => 'rhn_live', :description => 'Push to RHN Live', :push_type => 'rhn_live')
    targets[:rhn_stage] = PushTarget.create!(:name => 'rhn_stage', :description => 'Push to RHN Stage', :push_type => 'rhn_stage')
    targets[:ftp] = PushTarget.create!(:name => 'ftp', :description => 'Push to public FTP server', :push_type => 'ftp')
    targets[:cdn] = PushTarget.create!(:name => 'cdn', :description => 'Push to CDN Live', :push_type => 'cdn')
    
    cdn_products = ProductVersion.where("unused_push_types like '%cdn%'").map(&:product)
    Product.all.each do |prod|
      prod.push_targets << targets[:rhn_live]
      prod.push_targets << targets[:rhn_stage]
      prod.push_targets << targets[:ftp] if prod.allow_ftp?
      prod.push_targets << targets[:cdn] if cdn_products.include? prod
    end

    ProductVersion.all.each do |pv|
      next if pv.unused_push_types.nil?
      pv.unused_push_types.each do |t|
        ActivePushTarget.create!(:product_version => pv, :push_target => targets[t.to_sym])
      end
    end

    RhnStagePushJob.update_all(:push_target_id => targets[:rhn_stage])
    RhnLivePushJob.update_all(:push_target_id => targets[:rhn_live])
    FtpPushJob.update_all(:push_target_id => targets[:ftp])
    CdnPushJob.update_all(:push_target_id => targets[:cdn])
  end

  # See https://engineering.redhat.com/rt/Ticket/Display.html?id=240772
  # NB: you might have to change Settings.pub_push_targets if it doesn't
  # have hss_validate and hss_prod in it yet.
  desc "Create push targets for HSS internal products (RHCI)"
  task :setup_hss_push_targets => :environment do
    # Hack to make sure PushJob.valid_push_targets works as expected :/
    CdnStagePushJob

    # Create new push targets
    hss_validate = PushTarget.find_or_create_by_name_and_push_type_and_description(
      :name=>'hss_validate', :push_type=>'cdn_stage', :is_internal=>true, :description=>'Push to HSS Internal validation')

    hss_prod = PushTarget.find_or_create_by_name_and_push_type_and_description(
      :name=>'hss_prod', :push_type=>'cdn', :is_internal=>true, :description=>'Push to HSS Internal production')

    # Update product
    product = Product.find_by_short_name('RHCI')
    product.push_targets = [hss_validate, hss_prod]

    # Update product versions
    # (Actually there's only one, RHEL-6-RHCI1)
    product.product_versions.each do |product_version|
      product_version.push_targets = [hss_validate, hss_prod]
    end
  end
end
