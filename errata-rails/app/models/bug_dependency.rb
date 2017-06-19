class BugDependency < ActiveRecord::Base
  # bug and blocks_bug can be dangling references, since a bug might
  # block/depend on a bug not available in ET's DB, e.g. a restricted bug or
  # simply a bug we haven't fetched yet.
  belongs_to :bug
  belongs_to :blocks_bug,
             :class_name => 'Bug'

  # Given an Bugzilla::Rpc::RPCBug, creates and deletes BugDependency objects
  # according to the fetched blocks and depends_on information.
  def self.update_from_rpc(rpc_bug)
    bug_id             = rpc_bug.bug_id
    blocks_bug_ids     = rpc_bug.blocks
    depends_on_bug_ids = rpc_bug.depends_on

    # rpc_bug returns empty string for fields not included in the BZ response
    blocks_bug_ids     = [] if blocks_bug_ids.blank?
    depends_on_bug_ids = [] if depends_on_bug_ids.blank?

    # Delete any removed blockers
    remove_blocks_bugs = where(:bug_id => bug_id)
    remove_blocks_bugs = remove_blocks_bugs.where('blocks_bug_id not in (?)', blocks_bug_ids) if blocks_bug_ids.any?
    remove_blocks_bugs.delete_all

    # Delete any removed depends_on
    remove_depends_on_bugs = where(:blocks_bug_id => bug_id)
    remove_depends_on_bugs = remove_depends_on_bugs.where('bug_id not in (?)', depends_on_bug_ids) if depends_on_bug_ids.any?
    remove_depends_on_bugs.delete_all

    # Add any new blockers
    blocks_bug_ids.each do |blocks_bug_id|
      find_or_create_by_bug_id_and_blocks_bug_id(
        bug_id, blocks_bug_id)
    end

    # Add any new depends_on
    depends_on_bug_ids.each do |depends_on_bug_id|
      find_or_create_by_bug_id_and_blocks_bug_id(
        depends_on_bug_id, bug_id)
    end

    # Any referenced bug ID not currently in the database should be marked as
    # dirty; this way we'll fetch related bugs sooner rather than later.
    want_bug_ids = blocks_bug_ids + depends_on_bug_ids
    have_bug_ids = Bug.where(:id => want_bug_ids).pluck('distinct id')

    (want_bug_ids - have_bug_ids).each do |id|
      DirtyBug.mark_as_dirty!(id)
    end
  end
end
