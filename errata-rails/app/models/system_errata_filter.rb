class SystemErrataFilter < ErrataFilter

  scope :in_display_order,
    order('errata_filters.display_order ASC, errata_filters.id ASC')

  def self.default
    SystemErrataFilter.first || SystemErrataFilter.new(:filter_params=>ErrataFilter::FILTER_DEFAULTS)
  end
end
