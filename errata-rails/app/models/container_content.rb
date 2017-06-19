class ContainerContent < ActiveRecord::Base
  belongs_to :brew_build
  has_many :container_repos, :dependent => :destroy
  has_many :errata, :through => :container_repos
end
