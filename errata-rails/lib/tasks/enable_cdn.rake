namespace :push do
  desc 'Enable CDN stage push target globally'
  task :enable_cdn_stage => :environment do
    # We want to enable CDN stage everywhere, because all products are supposed to be
    # distributed by CDN.
    #
    # However, check if there's at least one live target enabled
    # first - if all live targets are disabled then there may be some special case.
    target = PushTarget.find_by_name!('cdn_stage')
    check_targets = PushTarget.where(:name => %w(rhn_live cdn))
    globally_enable_push_target(target, check_targets)
  end

  desc 'Enable CDN push target globally'
  task :enable_cdn => :environment do
    # We want to enable CDN live everywhere, because all products are supposed to be
    # distributed by CDN, and via ET pushing to CDN rather than the RHN -> CDN sync.
    #
    # However, do not enable CDN live unless CDN stage has already been enabled - we
    # expect that the above enable_cdn_stage has been run some time prior to this task,
    # and stage pushes fully tested.
    target = PushTarget.find_by_name!('cdn')
    check_targets = PushTarget.where(:name => %w(cdn_stage))
    globally_enable_push_target(target, check_targets)
  end

  # Enable the given push target for all active products / product versions / variants
  # in ET.
  #
  # If +check_targets+ is not empty, then those targets will be used as a reference:
  # for a given entity, if none of them are enabled, then +target+ also will not be
  # enabled and a warning will be logged.
  def globally_enable_push_target(target, check_targets)
    really = ENV['REALLY'] == '1'

    # Get all the enabled products, product versions and variants.
    # Note that we start from the top (product) and enumerate them because we don't want
    # to handle e.g. an enabled product version which belongs to a disabled product
    products = Product.active_products
    product_versions = products.
      map(&:product_versions).
      map(&:enabled).
      flatten.
      sort_by(&:name)
    variants = product_versions.map(&:variants).flatten.sort_by(&:name)

    # These objects all have push_targets with the same interface, to be checked and
    # modified
    all_objects = products + product_versions + variants

    modified = []
    ActiveRecord::Base.transaction do
      modified = enable_target(target, check_targets, all_objects)
      unless really
        raise ActiveRecord::Rollback
      end
    end

    # Find and print out any errata who may have had their applicable push targets
    # modified due to this. The idea is that the errata can be checked before and after
    # REALLY to determine if something changed in the workflow unexpectedly.
    modified_pv = modified.select{ |o| o.is_a?(ProductVersion) }
    modified_errata = modified_pv.map(&:errata).map(&:active).flatten.uniq

    if modified_errata.any?
      puts 'THESE ERRATA MAY BE AFFECTED:'
      modified_errata.sort_by(&:id).each do |e|
        puts ["https://#{ErrataSystem::SYSTEM_HOSTNAME}/advisory/#{e.id}",
              e.advisory_name,
              e.status,
              e.synopsis].join(' - ')
      end
    end

    unless really
      puts '(nothing has been changed. Run with REALLY=1 to really update data...)'
    end
  end

  # Enables the given push +target+ on +all_objects+, skipping and logging for any object
  # where none of +check_targets+ are already enabled.
  #
  # Returns an array of the objects which were modified.
  def enable_target(target, check_targets, all_objects)
    modified = []

    all_objects.each do |object|
      log = lambda do |msg|
        puts "#{object.class} #{object.name}: #{msg}"
      end

      current_targets = object.push_targets
      if current_targets.include?(target)
        log["SKIP: #{target.name} is already enabled"]
        next
      end

      if object.name.include?('RHEL-4') || object.name =~ /^4/
        log["SKIP: RHEL-4"]
        next
      end

      if check_targets.any? && !check_targets.any?{|t| current_targets.include?(t)}
        log[
          "SKIP: not enabling #{target.name} because none of these are enabled: " +
          check_targets.map(&:name).join(', ')
        ]
      end

      # Note that this does not execute the validations on Variant which attempt to
      # prevent modifying push targets of a variant if it has active errata. In this
      # case, that's desirable.
      object.push_targets << target
      modified << object
      log["enabled target #{target.name}"]
    end
  end
end
