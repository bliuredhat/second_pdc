class AddTicketFlagToPushJobs < ActiveRecord::Migration
  def self.up
    add_column :push_jobs, :problem_ticket_filed, :boolean, :default => false
  end

  def self.down
    remove_column :push_jobs, :problem_ticket_filed
  end
end
