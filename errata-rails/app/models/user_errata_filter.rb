class UserErrataFilter < ErrataFilter
  validates_presence_of :user_id
end
