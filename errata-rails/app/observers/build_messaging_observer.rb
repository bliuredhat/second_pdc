require 'message_bus/send_message_job'

class BuildMessagingObserver < ErrataBuildMappingObserver
  observe ErrataBrewMapping, PdcErrataReleaseBuild

  def after_save(mapping)
    saved_mappings << mapping
  end

  def after_rollback(*args)
    saved_mappings.clear
  end

  def after_commit(*args)
    begin
      saved_mappings.group_by{|m| [m.errata, m.brew_build]}.each do |(errata,build),mappings|
        maybe_send_message(errata, build, mappings)
      end
    ensure
      saved_mappings.clear
    end
  end

  private

  # Sends a build added/removed message if appropriate.
  # The messages are only send if all mappings for a build were added or obsoleted.
  def maybe_send_message(errata, build, mappings)
    all_obsoleted = mappings.all?{|m| obsoleted?(m)}
    all_new = mappings.all?{|m| new_record?(m)}

    if !all_obsoleted && !all_new
      Rails.logger.debug "#{build.nvr}: mixed add/remove mappings, no messages to publish."
      return
    end

    current_builds_count = errata.build_mappings.where(:brew_build_id => build).count

    if all_obsoleted && 0 == current_builds_count
      send_build_removed_message(errata, build)
      return
    elsif all_new && mappings.count == current_builds_count
      send_build_added_message(errata, build)
    end
  end

  def saved_mappings
    Thread.current[:build_messaging_observer_saved_mappings] ||= []
  end

  def send_build_removed_message(errata, build)
    MessageBus.send_message(
      get_msg_info(errata, build),
      'builds.removed',
      errata.is_embargoed?
    )

    send_builds_changed_message(errata, build, true)
  end

  def send_build_added_message(errata, build)
    MessageBus.send_message(
      get_msg_info(errata, build, :with_files => Settings.build_msgs_include_files),
      'builds.added',
      errata.is_embargoed?
    )

    send_builds_changed_message(errata, build)
  end

  def send_builds_changed_message(errata, build, is_removed = false)
    MessageBus.enqueue(
      'errata.builds.changed',
      get_msg_body(errata, build, is_removed),
      get_msg_header(errata, build),
      :embargoed => errata.is_embargoed?
    )
  end

  def get_msg_info(errata, build, opts={})
    msg = {
      'errata_id' => errata.id,
      'brew_build' => build.nvr,
      'when' => Time.zone.now.to_s(:db_time_now),
      'who' => User.current_user.login_name,
    }

    # Don't always need to include files so make it optional
    msg.merge!({
      'files' => build.brew_rpms.collect{ |r| r.file_path },
    }) if opts[:with_files]

    msg
  end

  def get_msg_body(errata, build, is_removed = false)
    msg_body = {
      'who' => User.current_user.login_name,
      'when' => Time.zone.now.to_s(:db_time_now),
      'errata_id' => errata.id,
      'added' => is_removed ? [].to_json : [build.nvr].to_json,
      'removed' => is_removed ? [build.nvr].to_json : [].to_json
    }
  end

  def get_msg_header(errata, build)
    msg_header = {
      'subject' => 'errata.builds.changed',
      'who' => User.current_user.login_name,
      'when' => Time.zone.now.to_s(:db_time_now),
      'errata_id' => errata.id
    }
  end
end
