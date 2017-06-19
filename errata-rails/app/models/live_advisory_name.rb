class LiveAdvisoryName < ActiveRecord::Base
  belongs_to :errata
  validates_uniqueness_of :live_id, :scope => :year

  def self.set_live_advisory!(errata)
    return if errata.has_live_id_set? || errata.product.is_internal?
    year = Time.now.year
    year += Settings.end_to_end_test_year_offset if errata.is_end_to_end_test?
    la = LiveAdvisoryName.transaction_with_retry do
      id = get_next_live_errata_id(year)
      la = LiveAdvisoryName.create!(:errata => errata, :year => year, :live_id => id)
      la.update_advisory_details
      la
    end
    la.add_live_change_comment
  end

  def self.get_next_live_errata_id(year)
    # Need to hold a lock on this until we've set the new max.  Other threads
    # might be calling set_live_advisory! at the same time.
    new_id = LiveAdvisoryName.where(:year => year).lock.maximum(:live_id)
    new_id ||= 0
    new_id + 1
  end

  def update_advisory_details
    # reload the errata to get the newly set live advisory name
    errata.reload

    old_advisory = errata.fulladvisory
    errata.set_fulladvisory
    errata.old_advisory = old_advisory
    errata.save!
  end

  def add_live_change_comment
    url = "http://errata.devel.redhat.com/advisory/#{errata.id}"
    msg = "NOTICE: #{errata.old_advisory} has changed its advisory name to #{errata.fulladvisory}\n" + url
    errata.comments << AdvisoryIdChangeComment.new(:text => msg)
  end
end
