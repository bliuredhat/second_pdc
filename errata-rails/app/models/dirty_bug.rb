class DirtyBug < DirtyRecord
   belongs_to :bug, :foreign_key => 'record_id'

   alias_attribute :bug_id, :record_id

   def self.engage
     max = Settings.max_bugs_per_sync || 1000
     super(max)
   end
end
