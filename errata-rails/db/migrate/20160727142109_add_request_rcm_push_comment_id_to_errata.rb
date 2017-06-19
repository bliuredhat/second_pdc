class AddRequestRcmPushCommentIdToErrata < ActiveRecord::Migration
  def change
    add_column :errata_main, :request_rcm_push_comment_id, :integer, :default => nil, :null => true
  end
end
