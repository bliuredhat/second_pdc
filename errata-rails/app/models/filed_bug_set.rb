# Coordinate the addition of a whole set of bugs.
# Adds all bugs in a single transaction, and adds a specialized
# comment to the advisory
class FiledBugSet < LinkSetBase
  def initialize(params = {})
    @bugs = params[:bugs]
    @errata = params[:errata]
    @user = params.fetch(:user, User.current_user)
    super(
      :new_link => lambda {|bug,errata| FiledBug.new(:bug => bug, :errata => errata)},
      :link_type => 'bug',
      :targets => @bugs,
      :errata => @errata
    )
  end

  def comment_class
    BugAddedComment
  end

  after_create do
    ReleaseComponent.assign_to_advisory @errata
  end
end
