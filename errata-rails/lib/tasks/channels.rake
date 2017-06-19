namespace :channels do

  #
  # Show channel details for a product_version
  #
  def display_channels(product_version,primary_only=false)
    if primary_only
      fmt = "%-6s %-15s %-30s %-10s %s"
      puts fmt % %w[ID VERSION VARIANT ARCH PRIMARY-CHANNEL ]
      puts fmt % %w[== ======= ======= ==== =============== ]
    end

    product_version.primary_channels.sort_by{|c|[c.variant.name,c.arch.name,c.name]}.each do |primary_channel|
      if primary_only
        puts fmt % [
          primary_channel.id,
          product_version.name,
          primary_channel.variant.name,
          primary_channel.arch.name,
          primary_channel.name.present? ? primary_channel.name : '(blank)'
        ]
      else
        puts "%s, %s, %s" % [product_version.name, primary_channel.variant.name, primary_channel.arch.name]
        fmt = " * %-20s: %s"
        puts fmt % ["Primary", primary_channel.name]
        primary_channel.sub_channels.sort_by{|c|c.type}.each do |sub_channel|
          puts fmt % [sub_channel.class.name, sub_channel.name]
        end
        puts ""
      end
    end
    puts ""
  end

  def display_primary_channels(product_version)
    display_channels(product_version,true)
  end

  #
  # Some utils for getting user confirmation
  # (Maybe should be moved somewhere for reuse)
  #
  def user_confirm(prompt,ok_string)
    print "#{prompt}: "
    STDIN.gets.chomp == ok_string
  end

  def user_confirm_commit
    user_confirm('Type OK to commit these changes, or anything else to rollback','OK')
  end

  def user_confirm_continue
    user_confirm('Type YES to continue','YES')
  end

  #
  # Wrapper tasks for display_channels above.
  # Specify a product name on the command line, eg:
  #  $ rake channels:show PV=RHEL-5.6.Z
  #
  desc "Display all channel details for a product version"
  task :show => :environment do
    display_channels(ProductVersion.find_by_name(ENV['PV'] || 'RHEL-5'))
  end

  desc "Display primary channel details for a product version"
  task :show_primary => :environment do
    display_primary_channels(ProductVersion.find_by_name(ENV['PV'] || 'RHEL-5'))
  end

  #
  # This is kind of a mess..
  #
  def get_required_primary_channel_for(rhel56z_channel)
    matches = ProductVersion.find_by_name('RHEL-5').primary_channels.select do |rhel5_channel|
      (
        # Have to munge the variant name to remove the suffix it seems...
        rhel5_channel.variant.name == rhel56z_channel.variant.name.sub(/-5\.6\.Z$/,'') &&
        rhel5_channel.arch_id == rhel56z_channel.arch_id
      )
    end
    raise "non-unique!" if matches.length > 1
    raise "not found!" if matches.empty?
    matches.first
  end

  #
  # A more generic version of the above, slightly less of a mess
  #
  def get_required_primary_channel(channel,variant_suffix,copy_from)
    # variant_suffix is probably something like '-5.6.Z'
    # It's because the variants are named with that suffix for RHEL-5.6.Z
    matches = copy_from.primary_channels.select do |copy_channel|
      ( "#{copy_channel.variant.name}#{variant_suffix}" == channel.variant.name &&
        copy_channel.arch_id == channel.arch_id )
    end
    raise "non-unique!" if matches.length > 1
    raise "not found!" if matches.empty?
    matches.first
  end

  #---------------------------------------------------------------------
  # See Bugzilla 723119. Need to put the primary channels
  # for RHEL-5.6.Z channels back to the same as the ones for RHEL-5
  # They were changed prematurely to the RHEL-5.7.Z channels.
  #
  # Also want to put the current primary channels in as EUS channels.
  #
  # (This predates the copy_primary and clear_primary)
  #
  desc "RHEL-5.6.Z channel juggling related to Bugzilla 723119"
  task :rhel56Z_juggle => :environment do

    dry_run = true # Set this false if you want to really do it..

    ProductVersion.find_by_name('RHEL-5.6.Z').primary_channels.each do |primary_channel|
      puts "\n============================"
      puts "#{primary_channel.name}/#{primary_channel.id}, " +
        "#{primary_channel.variant.name}/#{primary_channel.variant.id}, " +
        "#{primary_channel.arch.name}/#{primary_channel.arch.id} "
      puts ""

      required_channel = get_required_primary_channel_for(primary_channel)

      if required_channel.name == primary_channel.name
        puts "Already matches"

      else
        puts "need to change from #{primary_channel.name} to #{required_channel.name}"

        # But first, copy the channel into an EUS sub channel
        new_eus_channel_data = {
          # So it's a subchannel of the primary channel
          :primary_channel_id => primary_channel.id,

          # Copy most fields from the primary channel
          :product_version_id => primary_channel.product_version_id,
          :arch_id            => primary_channel.arch_id,
          :name               => primary_channel.name,
          :version_id         => primary_channel.version_id,
          :cdn_path           => primary_channel.cdn_path,
        }
        puts "create EUS channel:\n#{new_eus_channel_data.to_yaml}"

        if dry_run
          puts " ** DRY RUN **"
        else
          EusChannel.create(new_eus_channel_data)
          puts "Created new EUS channel!"
        end

        puts ""

        #
        # Change the name to match RHEL-5
        #
        puts "update primary channel to name=#{required_channel.name}, cdn_path=#{required_channel.cdn_path}"

        if dry_run
          puts " ** DRY RUN **"
        else
          primary_channel.name = required_channel.name
          primary_channel.cdn_path = required_channel.cdn_path
          primary_channel.save!
          puts "Primary channel updated!"
        end

        puts ""

      end
    end
  end

  #---------------------------------------------------------------------
  # tkopecek writes:
  # > one erratum missed push to main rhel channels. So we need to set up back
  # > primary channels for 5.6.z product repush it and then remove primary
  # > channels again.
  #
  # So let's write a script to clear primary channels and another one to copy
  # primary channels from another product version.
  #

  #
  # For clearing primary channels. Does not remove the records, just sets
  # the name field to an empty string.
  #
  desc "Clear primary channels for a given product version"
  task :clear_primary => :environment do
    pv_name = ENV['PV']                            or raise "You must specify a product version name!"
    pv      = ProductVersion.find_by_name(pv_name) or raise "Product version #{pv_name} not found!"
    (pv.name =~ /^RHEL-\d.\d.Z$/)                  or raise "This is for RHEL-X.Y.Z only" # for now...

    puts "BEFORE:"
    display_primary_channels(pv)

    print "The primary channels listed above will be set to an\n" +
      "empty string. Channel records will not be removed.\n\n"

    exit unless user_confirm_continue

    PrimaryChannel.transaction do
      # Do the updates
      pv.primary_channels.each do |primary_channel|
        primary_channel.name = ''
        primary_channel.save!
      end

      # Show result
      puts "UPDATED:"
      display_primary_channels(pv)

      # Commit or rollback
      raise "Let's roll back!" unless user_confirm_commit
    end
  end

  #
  # For copying primary channels from another product version.
  # Does not add records, just sets the name field of the existing record.
  #
  # Example:
  #  $ rake channels:copy_primary PV=RHEL-5.6.Z FROM_PV=RHEL-5
  #
  desc "Copy primary channels from one product version to another"
  task :copy_primary => :environment do
    to_pv_name   = ENV['TO_PV']   or raise "Specify a product version name to copy to!"
    from_pv_name = ENV['FROM_PV'] or raise "Specify a product version name to copy from!"

    to_pv   = ProductVersion.find_by_name(to_pv_name)   or raise "#{to_pv_name} not found!"
    from_pv = ProductVersion.find_by_name(from_pv_name) or raise "#{from_pv_name} not found!"

    # We make some assumptions about the variant suffix that depend on the from_pv_name
    # being something like RHEL-5 and the pv_name being something like RHEL-5.6.Z
    # So lets enforce that here, at least for now. In future this could become more general purpose.
    (to_pv.name =~ /^RHEL-\d.\d.Z$/ && from_pv.name =~ /^RHEL-\d$/) or raise "Use this for RHEL only!"

    puts "** COPY FROM:"
    display_primary_channels(from_pv)

    puts "** COPY TO:"
    display_primary_channels(to_pv)

    exit unless user_confirm_continue

    # This is the non-general purpose part... It will be something like '-5.6.Z'
    variant_suffix = to_pv.name.sub(/^RHEL/,'')

    PrimaryChannel.transaction do
      # Do the updates
      to_pv.primary_channels.each do |channel|
        channel.name = get_required_primary_channel(channel,variant_suffix,from_pv).name
        channel.save!
      end

      # Show the result
      puts "** UPDATED:"
      display_primary_channels(to_pv)

      # Commit or rollback
      raise "Let's roll back!" unless user_confirm_commit
    end
  end

  #
  # Append a suffix to the primary channels for a given product version
  #
  # Needed this once to put 5.6.Z back to how it was after copying the
  # RHEL-5 channels.
  #
  # Example:
  #  $ rake channels:append_suffix_to_primary PV=RHEL-5.6.Z SUFFIX=.6.z
  #
  desc "Append a suffix to the primary channels for a given product version"
  task :append_suffix_to_primary => :environment do
    pv_name = ENV['PV']     or raise "Specify a product version name to copy to!"
    suffix  = ENV['SUFFIX'] or raise "Specify the suffix to append!"

    pv = ProductVersion.find_by_name(pv_name) or raise "#{pv_name} not found!"

    (pv.name =~ /^RHEL-\d.\d.Z$/) or raise "Use this for RHEL X.Y.Z only!"

    puts "** BEFORE:"
    display_primary_channels(pv)

    exit unless user_confirm_continue

    PrimaryChannel.transaction do
      # Do the updates
      pv.primary_channels.each do |channel|
        channel.name = channel.name + suffix
        channel.save!
      end

      # Show the result
      puts "** UPDATED:"
      display_primary_channels(pv)

      # Commit or rollback
      raise "Let's roll back!" unless user_confirm_commit
    end
  end

end
