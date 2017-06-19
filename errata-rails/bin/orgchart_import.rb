#!/usr/bin/env ruby
require 'krb_cmd_setup'
include KrbCmdSetup
require 'xmlsimple'

MGMT_ROLE = Role.find_by_name('management')

def makeorg(group, parent)
  return unless group

  p "Making parent org: #{group['name']}"
  dg = UserOrganization.find_or_create_by_name(group['name'])
  dg.parent = parent
  dg.save!
  p "#{dg.name} has id #{dg.id}"
  
  people = group['person']
  if people
    people.each do |person|
      user = User.find_by_login_name(person['email'])
      next unless user
    
      dg.users << user
      if person['realname'] =~ /Manager/
        dg.manager = user
        unless user.in_role?('management')
          user.roles << MGMT_ROLE
        end
      end

    end
    dg.save!
  end

  subgroups = group['group']
  if subgroups
    p "Making parent org: " + subgroups.collect { |g| g['name']}.join(', ')
    subgroups.each { |sub| makeorg(sub, dg)}
  end
  p ""
end


raise "Need an XML export file of the org chart" unless ARGV.first
org = XmlSimple.xml_in(ARGV.first)

eng = UserOrganization.find_by_name('Engineering')

ErrataResponsibility.update_all("user_organization_id = #{eng.id}")
User.update_all("user_organization_id = #{eng.id}")
UserOrganization.update_all('parent_id = null')

makeorg(org,nil)

resp = ErrataResponsibility.find(:all, :include => [:default_owner])
resp.each { |r| r.user_organization = r.default_owner.organization }

noorg = User.find(:all, :conditions => 'user_organization_id is null')


noorg.each do |u|
 u.organization = eng
 u.save
end


UserOrganization.delete_all('parent_id = null')
