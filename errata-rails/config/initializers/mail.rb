MAIL = {
  # All (most?) email will be sent using this from address
  'from'                            => 'bugzilla@redhat.com', # TODO: change this?

  # Some default mail recipients
  'default_docs_user'               => 'docs-errata-list@redhat.com',
  'default_docs_owner'              => 'qa-errata-list@redhat.com',
  'default_qa_user'                 => 'qa-errata-list@redhat.com',
  'default_security_user'           => 'security-response-team@redhat.com',
  'dev_recipient'                   => "#{ENV['USER']}@redhat.com",
}
