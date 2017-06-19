module WithStubbedConst
  def with_stubbed_const(consts, scope=self.class)
    stash = {}
    consts.each_pair do |key, val|
      stash[key] = scope.send(:remove_const, key)
      scope.send(:const_set, key, val)
    end

    begin
      yield
    ensure
      consts.each_pair do |key, val|
        scope.send(:remove_const, key)
        scope.send(:const_set, key, stash[key])
      end
    end
  end
end
