# Dummy Config - cfengine managed

module RHN
  PUSH_SERVER = { 
    :stage => { 
      :server => 'stage-server',
      :user => 'the-user',
      :password => 'the-passwd'
    },
    :live => { 
      :server => 'live-server',
      :user => 'the-user',
      :password => 'the-passwd'
    }
  }.freeze
end
