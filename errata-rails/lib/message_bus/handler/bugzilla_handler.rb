module MessageBus::Handler::BugzillaHandler
  extend ActiveSupport::Concern

  included do |klass|
    address = Settings.mbus_bugzilla_address
    props   = Settings.mbus_bugzilla_properties
    klass.subscribe(address, props) do |messages|
      MessageBus::Handler::BugzillaHandler.handle(messages)
    end
  end

  def self.handle(messages)
    return unless Settings.mbus_bugzilla_sync_enabled
    bug_ids = messages.map{|msg| JSON.parse(msg.body)['bug_id']}
    (to_update,to_create) = bug_ids.to_set.reject(&:nil?).partition{|b| Bug.exists?(b)}
    update_bugs(to_update)
    create_bugs(to_create)
  end

  def self.update_bugs(ids)
    return if ids.empty?
    mark_dirty_bugs(ids)
    BUGLOG.info "Marked #{ids.size} bugs dirty."
  end

  def self.create_bugs(ids)
    return if ids.empty?
    mark_dirty_bugs(ids)
    BUGLOG.info "Requested creation of #{ids.size} bugs."
  end

  private

  def self.mark_dirty_bugs(ids)
    # Mark the the bugs as dirty, so that the UpdateDirtyBugsJob can process them later.
    ids.each do |id|
      DirtyBug.mark_as_dirty!(id)
    end
  end
end
