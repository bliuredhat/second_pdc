#
# ***
# *** This is mostly obsolete now because we use Gerrit
# ***
#
# Save me some time with small bugs.
# Generate bug comment boilerplate to copy/paste.
#
# TODO maybe: Actually add the comment automatically
# via bugzilla xmlrpc and change status to modified.
#
namespace :dev_bug_comment do

  #
  # This doesn't cover all cases, eg it's no good for a commit done
  # directly in an RC branch.
  #
  desc "Generate Bugzilla comment boilerplate (single commit, push to personal repo)"
  task :single do
    current_branch = get_current_branch_from_git
    current_commit_hash = get_current_commit_hash_from_git

    bug_number = current_branch.split(/_/).first # for branch called 812312_foo_bar
    user = ENV['USER']

    remote_name = case user
    when 'sbaird'
      'simon'
    else
      user
    end

    commit_diff_url = "http://git.engineering.redhat.com/?p=users/#{user}/errata-rails.git;a=commitdiff;h=#{current_commit_hash}"

    puts "-------------------------------------

Updates here:
  #{commit_diff_url}

Branch to merge:
  #{remote_name}/#{current_branch}

-------------------------------------

Remember to push if you didn't already, ie:

  git push #{remote_name} #{current_branch}

Bug link:

  https://bugzilla.redhat.com/show_bug.cgi?id=#{bug_number}#add_comment

"
  end

end
