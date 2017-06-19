module ErrataWorkflow
  extend ActiveSupport::Concern

  def workflow_steps
    return text_only_steps if self.text_only?
    [
     :edit,
     :update_brew_builds,
     (:update_brew_file_meta if self.has_brew_files_requiring_meta?),
     (:rpm_diff_finished if self.requires_rpmdiff?),
     (:external_tests_finished if self.requires_external_tests_for_qe?),
     (:abi_diff_finished if self.requires_abidiff?),
     # TPS runs appear when advisory goes to QE. Maybe should show a message instead of hiding this..
     (:tps_finished if (self.requires_tps? && self.tps_run)),
     (:set_metadata_cdn_repos if self.supports_cdn_docker? || self.supports_cdn_docker_stage?),
     :view_qa_request,
     (:rpm_diff_review_finished if self.requires_rpmdiff?),
     (:docs_approval if self.requires_docs?),
     :sign_advisory,
     # QUESTION: Should we have a no_rhn_stage and no_rhn_live like ftp does?
     (:stage_push if self.supports_rhn_stage? ),
     (:cdn_stage_push if self.supports_cdn_stage? ),
     (:cdn_docker_stage_push if self.supports_cdn_docker_stage? ),
     (:rhnqa_finished if (self.requires_tps? && self.tps_run && self.rhnqa?)),
     (:security_approval if self.requires_security_approval?),
     (:rcm_push_requested if self.rcm_push_requested?),
     (:live_push if self.supports_rhn_live?),
     (self.product.allow_ftp? ? :ftp_push : :no_ftp_push),
     (:cdn_push if self.supports_cdn?),
     (:cdn_docker_push if self.supports_cdn_docker?),
     (:altsrc_push if self.supports_altsrc?),
     (:ccat_verify if self.use_ccat?),
     (:mail_announcement if self.is_security?),
     :close_advisory,
    ].compact
  end

  def text_only_steps
    [
     :edit,
     :view_qa_request,
     :set_text_only_rhn_channels,
     (:docs_approval if self.requires_docs?),
     (:stage_push if self.supports_rhn_stage?),
     (:cdn_stage_push if self.supports_cdn_stage?),
     (:security_approval if self.requires_security_approval?),
     (:rcm_push_requested if self.rcm_push_requested?),
     (:live_push if self.supports_rhn_live?),
     (self.product.allow_ftp? ? :ftp_push : :no_ftp_push),
     (:cdn_push if self.supports_cdn?),
     (:altsrc_push if self.supports_altsrc?),
     (:ccat_verify if self.use_ccat?),
     (:mail_announcement if self.is_security?),
     :close_advisory,
    ].compact
  end

end
