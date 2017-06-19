class AddCdnStagePushTarget < ActiveRecord::Migration

  def up
    target = PushTarget.find_by_name(new_push_name)
    return say "Target present, doing nothing!" if target.present?

    # Annoying hack so PushJob.descendants works since it is used in the
    # PushTarget validations. (See also config/environments/development.rb)
    [RhnStagePushJob,RhnLivePushJob,CdnPushJob,CdnStagePushJob,FtpPushJob]

    # Make sure the the cdn_stage pub push target exists.
    # (Because settings in the database have precedence, we can't assume that the
    # cdn_stage push target exists even though we added it to the defaults in settings.rb).
    unless Settings.pub_push_targets.has_key?(new_push_name)
      # (Make sure we use the settings assignment method so it persists properly)
      Settings.pub_push_targets = Settings.pub_push_targets.merge(new_push_name => { 'target' => new_push_target })
    end

    target = PushTarget.create!(:name => new_push_name,
                                :description => 'Push to CDN Stage',
                                :push_type => new_push_type)

    product_to_change.push_targets << target

    # (Considered adding to rhel-7 product version, but decided not to
    # until pub guys tell us it's ready)

    say "Created push target #{target.inspect}"
  end

  def down
    target = PushTarget.find_by_name(new_push_name)
    return say "Target not found, doing nothing!" if target.nil?

    product_to_change.push_targets.delete(target)
    target.delete

    # (Won't worry about removing 'cdn_stage' from pub_push_targets)

    say "Deleted push target #{target.inspect}"
  end

  def new_push_name
    'cdn_stage'
  end

  def new_push_type
    'cdn_stage'
  end

  def new_push_target
    Rails.env.production? ? 'cdn-stage' : 'webdev'
  end

  def product_to_change
    Product.find_by_short_name('RHEL')
  end

end

