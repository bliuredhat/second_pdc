class CreateAdvisoryForm < AdvisoryForm

  def set_advisory
    type = params[:advisory][:errata_type] || (params[:is_pdc] ? 'PdcRHBA' : 'RHBA')
    klass = Errata.child_get(type)
    self.errata = klass.new
    self.errata.content = Content.new
    self.errata.reporter = who
  end

end
