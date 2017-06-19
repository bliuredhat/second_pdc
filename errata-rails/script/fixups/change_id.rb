# Script for renumbering 9000+ errata ids
# group_name - Name of errata group to update advisories for; e.g. RHEL4-QU17
#
def renumber_ids(group_name)

  release = Release.find(:first, :conditions => ["name = ?", group_name])
  raise "No such group named: #{group_name}!" unless release

  errata = release.errata.find(:all,
                               :conditions => ['is_valid = 1 and status not in (?) and errata_id < 8000', ['SHIPPED_LIVE', 'DROPPED_NO_SHIP']])

  unless errata.length > 0
    p "No advisories found for #{group_name}"
    return
  end

  p "Renumbering #{errata.size} advisories with new errata_ids starting at #{errata.first.get_next_errata_id}"

  errata.each do |e|
    change_id(e, e.get_next_errata_id(Time.now.year))
  end
end

def get_next_id
  year = Time.now.year.to_s
  max_id = Errata.maximum :errata_id, :conditions => "fulladvisory like '%#{year}%' and errata_id < 8000"
  next_id = max_id + 1
end

def change_id(errata, next_id)
  newadvisory = errata.errata_type +
    "-#{Time.now.year}:" +
    sprintf("%.4d", next_id) +
    "-" +
    sprintf("%.2d", errata.revision)

  old_advisory = errata.fulladvisory
  p "Changing #{errata.id} - #{old_advisory} to #{newadvisory}"
  url = "http://errata.devel.redhat.com/errata/showrequest.cgi?advisory=#{errata.id}"

  beforemsg = "NOTICE: #{old_advisory} will be changing its advisory id to #{newadvisory}\n" + url
  errata.comments << AdvisoryIdChangeComment.new(:text => beforemsg)

  errata.fulladvisory = newadvisory
  errata.old_advisory = old_advisory
  errata.errata_id = next_id
  errata.save

  errata.rpmdiff_runs.each do |r|
    r.errata_nr = errata.shortadvisory
    r.save
  end

  aftermsg = "NOTICE: #{errata.fulladvisory} has changed its advisory id to #{newadvisory}\n" + url
  errata.comments << AdvisoryIdChangeComment.new(:text => aftermsg)
end
