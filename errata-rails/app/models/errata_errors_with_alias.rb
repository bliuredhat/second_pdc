class ErrataErrorsWithAlias < ErrorsWithAlias
  def initialize(delegate)
    super delegate,
          # See bug 1287399: form object reads this attribute as
          # `synopsis_sans_impact' and writes it as `synopsis'
          :synopsis_sans_impact => :synopsis
  end
end
