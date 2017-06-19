# See http://ryanangilly.com/post/234897271/dynamically-adding-class-methods-in-ruby
module DefineClassMethod
  def define_class_method(name, &block)
    (class << self; self; end).instance_eval { define_method(name, &block) }
  end
end
