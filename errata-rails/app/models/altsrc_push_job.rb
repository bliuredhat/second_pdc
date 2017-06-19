class AltsrcPushJob < PushJob
  def push_details
    {
      'can' => errata.can_push_altsrc?,
      'blockers' => errata.push_altsrc_blockers,
      'target' => self.target
    }
  end
end
