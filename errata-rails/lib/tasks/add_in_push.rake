
namespace :workflow_rules do
  desc "Adds the IN_PUSH state and relevant transitions; removes direct PUSH_READY => SHIPPED_LIVE"
  task :add_in_push => :environment do
    StateTransition.transaction do
      pi = StateTransition.create!(:from => 'PUSH_READY', :to => 'IN_PUSH', :roles => ['releng'], :is_user_selectable => false)
      is = StateTransition.create!(:from => 'IN_PUSH', :to => 'SHIPPED_LIVE', :roles => ['releng'], :is_user_selectable => false)
      ir = StateTransition.create!(:from => 'IN_PUSH', :to => 'REL_PREP', :roles => ['releng'], :is_user_selectable => false)

      ps = StateTransition.find_by_from_and_to 'PUSH_READY', 'SHIPPED_LIVE'
      ps_guards = StateTransitionGuard.where(:state_transition_id => ps)
      ps_guards.each { |g| g.update_attribute(:state_transition, pi)  }
      ps.delete
    end
  end
end
