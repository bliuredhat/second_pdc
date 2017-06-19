#
# NB: This is a utility class for doing some validations
# and has no database records.
#
class Contact
  include ActiveModel::Validations
  attr_reader :email, :user
  validate :check_email

  def initialize(email)
    @email = email
    @user = User.find_by_login_name(@email)
  end

  def login_name
    @email
  end

  protected
  def check_email
    if email.blank?
      errors.add_on_blank(:email)
      return
    end

    unless @user
      errors.add(:email, "Not a valid errata user")
    end
  end
end
