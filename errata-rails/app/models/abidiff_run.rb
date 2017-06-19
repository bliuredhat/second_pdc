class AbidiffRun < ActiveRecord::Base
  belongs_to :errata
  belongs_to :brew_build
  validates_presence_of :errata, :brew_build, :status, :timestamp
  scope :current, where(:current => true)
  scope :started, current.where(:status => 'STARTED')
  scope :failed, current.where(:status => 'FAILED')
  scope :passed, current.where(:status => 'COMPLETE', :result => ['ACKDIFF', 'NODIFF'])

  scope :incomplete, current.where(:status => ['STARTED', 'FAILED'])
  scope :blocking, current.where(:status => 'COMPLETE', :result => 'BLOCK')

  def self.invalidate_runs(errata, build)
    self.current.where(:errata_id => errata, :brew_build_id => build).update_all(:current => false)
  end
end
