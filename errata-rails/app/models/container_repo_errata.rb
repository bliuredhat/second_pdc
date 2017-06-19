class ContainerRepoErrata < ActiveRecord::Base
  belongs_to :container_repo
  belongs_to :errata
end
