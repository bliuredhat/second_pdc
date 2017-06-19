namespace :debug do
  namespace :test_user do

    def tu
      @@_test_user ||= begin
        User.find_by_name(ENV['ET_USER']||'') || User.fake_devel_user
      end
    end

    def show_tu_roles
      puts tu.roles.map(&:name).sort.join(', ')
    end

    desc "Show test user roles"
    task :show_roles => :environment do
      show_tu_roles
    end

    desc "Remove test user role (use ROLE=foo to specify role)"
    task :rm_role => [:environment, :not_production] do
      tu.remove_role ENV['ROLE']
      show_tu_roles
    end

    desc "Add test user role (use ROLE=foo to specify role)"
    task :add_role => [:environment, :not_production] do
      tu.add_role ENV['ROLE']
      show_tu_roles
    end

    desc "Restore test user roles"
    task :restore_roles => [:environment, :development_only] do
      tu.roles = Role.all_except_readonly
      show_tu_roles
    end

    desc "Set test user to just the roles specified"
    task :set_roles => [:environment, :not_production] do
      tu.replace_roles('errata', ENV['ROLE'].split(','))
      show_tu_roles
    end

  end
end

# This doesn't really belong here, but I don't want to make a whole new rake file...
namespace :one_time_scripts do
  desc "create super user role"
  task :create_super_user_role => :environment do
    new_role = Role.create(:name=>'super-user', :description=>'Can perform application level configuration. Mainly for use by Errata Tool developers.')
    User.find_by_name('sbaird').roles << new_role
    User.find_by_name('jorris').roles << new_role
  end

  desc "create covscan admin role"
  task :create_covscan_admin_role => :environment do
    new_role = Role.create(:name=>'covscan-admin', :description=>'Can reschedule Covscan runs and view Covscan related reports')
    ['ttomecek', 'ovasik', 'kdudka', 'praiskup'].each do |user_name|
      User.find_by_name(user_name).roles << new_role
    end
  end
end
