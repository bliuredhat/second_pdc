class DroppedBugSet < LinkSetBase
  def initialize(params = {})
    @bugs = params[:bugs]
    @errata = params[:errata]
    @user = params.fetch(:user, User.current_user)
    super(
      :new_link => lambda {|bug,errata| DroppedBug.new(:errata => errata, :bug => bug)},
      :link_type => 'bug',
      :operation => 'removed',
      :targets => @bugs,
      :errata => @errata,
      :persist_links => lambda {|bugs| @errata.filed_bugs.where(:bug_id => bugs).destroy_all }
    )
  end

  def comment_class
    BugRemovedComment
  end

  after_create do
    ReleaseComponent.unassign_from_advisory(@errata, @bugs.map(&:package_id))
  end
end
