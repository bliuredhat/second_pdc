module TextRender
  class OvalRenderer < ErrataRenderer
    def initialize(errata)
      super(errata, 'push/errata_oval')
      @test = OvalTest.new(errata)
    end
  end
end
