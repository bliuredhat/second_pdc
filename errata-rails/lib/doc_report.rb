include ActionView::Helpers::DateHelper

def docs_report(from, to)
  
  report = []
  
  approvals = ErrataActivity.find(:all, 
                                  :conditions => 
                                  ["what = ? and errata_activities.created_at >= ? and errata_activities.created_at <= ?", 
                                   'docs_approved', from, to], 
                                  :include => [:errata, :who],
                                  :order => 'errata_activities.errata_id, errata_activities.created_at desc')
  
  app_types = Hash.new(0)
  approved_errata = Set.new
  approvals.each do |a| 
    next if approved_errata.include?(a.errata)
    approved_errata << a.errata
    app_types[a.errata.errata_type] += 1
  end

  report << "Docs Errata Activity Summary, #{from.to_date.to_s(:long)} to #{to.to_date.to_s(:long)}"
  report << ""
  report << "## Approved ##"
  total = 0
  app_types.each_pair do |type, count|
    total += count
    report << "#{type}  #{sprintf("%.2d", count)}"
  end
  report << "---------"
  report << "Total:  #{sprintf("%.2d", total)}"
  report << ""
  

  open_requests = ErrataActivity.find(:all, 
                                      :conditions => 
                                      ["what = ? and errata_activities.created_at >= ? and errata_activities.created_at <= ? and errata_activities.errata_id not in (?)", 
                                       'docs_approval_requested', from, to, approved_errata.to_a], 
                                      :include => [:errata, :who],
                                      :order => 'errata_activities.errata_id, errata_activities.created_at desc')

  open_types = Hash.new(0)
  open_errata = Set.new
  open_requests.each do |a| 
    next if open_errata.include?(a.errata)
    open_errata << a.errata
    open_types[a.errata.errata_type] += 1
  end


  report << "## Still Open ##"
  total = 0
  open_types.each_pair do |type, count|
    total += count
    report << "#{type}  #{sprintf("%.2d", count)}"
    end
  report << "---------"
  report << "Total:  #{sprintf("%.2d", total)}"
  report << ""
  

  
  report << "Docs Errata Approved:" unless approvals.empty?
  last_errata = nil
  approvals.each do |a|
    next if a.errata == last_errata
    last_errata = a.errata
    report.concat(report_on(a.errata, a.who, a.created_at, from, to))
  end

  report << "Docs Errata Still Open:" unless approvals.empty?
  last_errata = nil
  open_requests.each do |a|
    next if a.errata == last_errata
    last_errata = a.errata
    report.concat(report_on(a.errata, a.who, a.created_at, from, to))
  end

  
  return report  

end

def report_on(errata, docs_owner, last_activity_at, from, to)
  report = []
  report << "errata type: #{errata.advisory_name}"
  report << "synopsis: #{errata.synopsis}"
  report << "docs owner: #{docs_owner.to_s}"
  
  requested = errata.activities.find(:first, 
                                       :conditions => 
                                       ["what = ? and created_at <= ?", 
                                        'docs_approval_requested', 
                                        last_activity_at],
                                       :order => 'created_at desc')
  
  
  if requested
    hold_time = distance_of_time_in_words( requested.created_at, last_activity_at)
  else
    hold_time = "-"
  end
  report << "hold time: #{hold_time}"
  
  report << "diffs:"
  diffs = errata.text_diffs.find(:all,
                                 :conditions => ["text_diffs.created_at >= ? and text_diffs.created_at <= ?",
                                                 from, to],
                                   :order => 'created_at desc')
  diffs.each {|d| report << "https://errata.devel.redhat.com/docs/diff_history/#{errata.id}##{d.id}" }
  report << ""
  report << ""
  report << ""
  
  
end


def weeks_since(date)
  
  weeks = []
  start_of_next_week =  Time.now.at_beginning_of_week.next_week
  
  week = date.at_beginning_of_week
  while(week < start_of_next_week)
    weeks.unshift week
    week = week.next_week
  end
  return weeks
  
end
