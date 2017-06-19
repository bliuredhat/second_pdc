# NOTE: Migration does a NO-OP and is maintained so that rake db:migrate is
# not confused by a missing migration file. Also, Ansible migration check
# step does some fancy things to decide about rollbacks, so keeping the
# migration file that is NO-OP is the safest option.

class RemovePdcPlaceholderReleaseAndProduct < ActiveRecord::Migration
  def change
  end
end
