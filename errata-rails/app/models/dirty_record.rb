class DirtyRecord < ActiveRecord::Base
  def engaged?
    self.status == 'engaged'
  end

  def mark_as_clean
    self.delete if self.engaged?
  end

  def self.mark_as_dirty!(outdated_record_id, changed_date = Time.now)
    # If changed_date is not set, it assumes the record had just been changed.
    # So default is now()
    dirty_records = self.where(:record_id => outdated_record_id).to_a

    # Create a new entry if the outdated record is not in the dirty list.
    # If the outdated record exists in the dirty list but is engaging
    # by the update bug/jira_record delayed job and changed date is newer,
    # then create a new entry to re-sync it later.
    if dirty_records.empty? ||
      (
        dirty_records.length == 1 &&
        dirty_records.first.engaged? &&
        dirty_records.first.last_updated < changed_date
      )
      self.create!(:record_id => outdated_record_id, :last_updated => changed_date)
    end
    outdated_record_id
  end

  def self.engage(max_records_per_sync)
    engaged = self.where(:status => 'engaged')

    # Make sure we don't have any deadlock from previous sync. If yes, then
    # process them first
    can_engage = max_records_per_sync - engaged.count

    # If we still have vacancies, then engage more dirty records.
    if can_engage > 0
      # older record first
      self.where(:status => nil).order('last_updated asc').limit(can_engage).update_all(:status => 'engaged')
    end

    return engaged.limit(max_records_per_sync).pluck(:record_id)
  end
end
