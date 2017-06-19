class AddCreateasyncRole < ActiveRecord::Migration
  def self.up

    #
    # Add the 'createasync' role.
    # See Bug 1196317.
    #
    createasync_role = Role.find_by_name(createasync_role_name)
    return say "Createasync role already exists" if createasync_role.present?

    ActiveRecord::Base.transaction do

      createasync_role = Role.create(
        :name        => createasync_role_name,
        :description => 'The Createasync role can create ASYNC advisories'
      )

      # Users with the 'pusherrata' role can create async advisories
      # already, so add all pusherrata users to the createasync role.

      User.with_role('pusherrata').each do |user|
        user.add_role(createasync_role_name)
      end

    end

  end

  def self.down

    createasync_role = Role.find_by_name(createasync_role_name)
    return say "Createasync role does not exist" if createasync_role.nil?

    User.with_role(createasync_role_name).each do |user|
      user.remove_role(createasync_role_name)
    end

    createasync_role.delete

  end

  def createasync_role_name
    'createasync'
  end

end
