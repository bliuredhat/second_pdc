require 'active_support/concern'

module SharedApi::Users
  extend ActiveSupport::Concern

  included do
    use_helper_method :role_change_message
  end

  def find_user_by_id_or_name(id_or_name)
    return nil unless id_or_name.present?
    if (id_or_name.to_s =~ /^\d+$/)
      method = "find_by_id"
    else
      method = "find_by_name"
    end
    return User.send(method, id_or_name)
  end

  def find_with_finger(name)
    name.present? ? FingerUser.new(name).name_hash : nil
  end

  def create_new_user
    return unless @user_params.present?

    @user = User.new(:login_name => @user_params[:login_name])
    set_user_details

    @notice = (ERB::Util::html_escape("User #{@user.realname} < #{@user.login_name} > " +\
      "account has been created successfully.\n\n") + @notice).gsub(/\n/,'<br/>').html_safe
    @user.reload
  end

  def set_user_details
    return unless @user_params.present?

    finger_user = find_with_finger(@user.login_name)

    fields = [:receives_mail, :email_address, :enabled, :roles, :organization]

    if finger_user.nil?
      # only allow special/machine user to update these fields
      fields = fields.concat([:login_name, :realname])

      # For machine user, automatically set 'receives_mail' to false if
      # 'email_address is not given
      @user_params[:receives_mail] = false if @user_params[:email_address].blank?
    elsif @user.new_record?
      # user the info from finger for real user
      @user.login_name = finger_user[:login_name]
      @user.realname = finger_user[:realname]
    end

    # disabling the errata role by this action is not permitted
    @user_params[:roles] ||= []
    (@user_params[:roles] << Role.find_by_name('errata')).uniq!

    old_roles = @user.roles.sort_by(&:name)
    new_roles = @user_params[:roles].sort_by(&:name)

    fields.each do |key|
      next unless @user_params.has_key?(key)
      @user.send("#{key}=", @user_params[key])
    end

    if @user.new_record? || (@user.changed? || old_roles != new_roles)
      # Something changed so update the user
      old_values = @user.old_values
      @user.save!

      change_message = role_change_message(old_values, old_roles, new_roles, @user)
      @notice = ERB::Util::html_escape(change_message)

      # Send notification if persisted user and user is allowed to receive mail
      if @user.persisted? && @user.receives_mail
        # Send a notification email
        Notifier.user_roles_change(@user, current_user, change_message).deliver
        @notice += "\n\nA notification email has been sent to #{ERB::Util::html_escape(@user.email)}"
      end
      @notice = @notice.gsub(/\n/,'<br/>').html_safe
    else
      # Nothing changed
      @notice = 'No changes.'
    end
  end
end
