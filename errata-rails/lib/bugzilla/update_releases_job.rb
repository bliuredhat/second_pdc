# Delayed job to update metadata associated with releases (e.g. ACL)
module Bugzilla
  class UpdateReleasesJob
    def perform
      BUGRECON.info 'Beginning update of release info'

      updated = 0
      failed = 0

      Release.current.enabled.select(&:can_update_bugs?).each do |release|
        begin
          release.update_bugs_from_rpc
          updated += 1
        rescue StandardError => ex
          BUGRECON.error "Couldn't update info for release #{release.name}: #{ex.inspect}"
          failed += 1
        end
      end

      raise 'all releases failed to update' if updated == 0 && failed != 0

      BUGRECON.info "Updated release info for #{updated} releases"
    end

    def rerun?
      true
    end

    def next_run_time
      22.hours.from_now
    end

    def self.enqueue_once
      Delayed::Job.enqueue_once self.new, 5
    end

    def to_s
      "Update approved components for active releases"
    end
  end
end
