class ErrataResponsibility < ActiveRecord::Base
  extend UrlFinder
  belongs_to :default_owner,
  :class_name => 'User',
  :foreign_key => 'default_owner_id'
  belongs_to :user_organization

  before_create do
    unless self.url_name
      self.url_name = self.opml_name
    end
    
    unless self.user_organization
      self.user_organization = UserOrganization.find_by_name('Engineering')
    end
    unless self.default_owner
      self.default_owner = self.user_organization.manager
    end
  end
  
  def description
    return name
  end
  
  def opml_name
    return name.downcase.gsub('-', ' ').split(' ').join('_')
  end
  
  def supports_opml?
    return true
  end
end
