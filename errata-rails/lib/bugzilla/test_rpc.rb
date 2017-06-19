module Bugzilla
  class TestRpc
    def get_bugs(bug_list, opts = {})
      begin
        bugs = Bug.find(bug_list)
      rescue ActiveRecord::RecordNotFound
        bugs = []
      end
      rpc = []
      bugs.each do |b|
        flags = []
        unless b.flags.blank?
          b.flags.split(',').each do |f|
            f.strip!
            name = f.chop
            status = f.last
            flags << {'name' => name, 'status' => status}
          end
        end
        h = { 'id' => b.id,
          'flags' => flags,
          'status' => b.bug_status,
          'summary' => b.short_desc,
          'component' => [b.package.name],
          'cf_qa_whiteboard' => b.qa_whiteboard,
          'cf_pm_score' => b.pm_score,
          'keywords' => b.keywords
        }
        
        h['product'] = 'Security Response' if b.is_security?
        rpc << Bugzilla::Rpc::RPCBug.new(h)
      end
      return rpc
    end

    def reconcile_bugs(bug_ids, updated_since = nil)
    end
  end
end
