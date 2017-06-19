module WithStubbedClassVariable

  ##
  # Allows setting or overriding of class variables
  # within a code block. The previous values are
  # restored when the block has completed.

  def with_stubbed_class_variable(vars, klass)
    raise TypeError, "Must specify a Class" unless klass.is_a? Class

    stash = {}
    new_vars = []
    vars.each_pair do |key, val|
      if klass.class_variable_defined?(key)
        stash[key] = klass.send(:class_variable_get, key)
      else
        new_vars.push(key)
      end
      klass.send(:class_variable_set, key, val)
    end

    begin
      yield
    ensure
      stash.each_pair do |key, val|
        klass.send(:class_variable_set, key, stash[key])
      end
      new_vars.each do |key|
        klass.send(:remove_class_variable, key)
      end
    end
  end
end
