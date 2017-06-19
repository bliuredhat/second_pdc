require 'test_helper'

class BzTableHelperTest < ActiveSupport::TestCase
  include BzTableHelper

  test 'compose row function executes the passed row blocks' do
    composed = compose_row_function(
      [
        lambda {|x,opts| "value is #{x}"},
        lambda {|x,opts| "2*value is #{x*2}"},
      ]
    )

    actual = [1,1,2,2].map do |row_value|
      composed.call(row_value)
    end

    assert_array_equal [
      'value is 1',
      '2*value is 2',
      'value is 2',
      '2*value is 4',
    ], actual
  end

  test 'compose row function executes the passed symbols' do
    def testfn1(x,opts)
      "value1: #{x}"
    end

    def testfn2(x,opts)
      "value2: #{x}"
    end

    composed = compose_row_function([:testfn1, :testfn2])

    actual = [1,1,2,2].map do |row_value|
      composed.call(row_value)
    end

    assert_array_equal [
      'value1: 1',
      'value2: 1',
      'value1: 2',
      'value2: 2',
    ], actual
  end

  test 'compose row function alternates even/odd as expected' do
    composed = compose_row_function(
      [
        lambda {|x,opts| "class 1 is #{opts[:class]}"},
        lambda {|x,opts| "class 2 is #{opts[:class]}"},
      ]
    )

    actual = ([1]*4).map do |x|
      composed.call(x)
    end

    assert_array_equal [
      'class 1 is bz_even',
      'class 2 is bz_even',
      'class 1 is bz_odd',
      'class 2 is bz_odd',
    ], actual
  end

  test 'compose row function hides internal borders' do
    composed = compose_row_function(
      [
        lambda {|x,opts| "style1: #{opts[:style]}"},
        lambda {|x,opts| "style2: #{opts[:style]}"},
        lambda {|x,opts| "style3: #{opts[:style]}"},
      ]
    )

    actual = ([1]*6).map do |x|
      composed.call(x)
    end

    assert_array_equal [
      'style1: border-bottom:none!important',
      'style2: border-top:none!important;border-bottom:none!important',
      'style3: border-top:none!important',
    ]*2, actual
  end

  test 'compose row function adds border to existing style if any' do
    composed = compose_row_function(
      [
        lambda {|x,opts| "style1: #{opts[:style]}"},
        lambda {|x,opts| "style2: #{opts[:style]}"},
      ],
      :style => 'my-style'
    )

    actual = ([1]*4).map do |x|
      composed.call(x)
    end

    assert_array_equal [
      'style1: my-style;border-bottom:none!important',
      'style2: my-style;border-top:none!important',
    ]*2, actual
  end

  test 'compose row function leaves border alone for a single function' do
    composed = compose_row_function([lambda {|x,opts| "style: #{opts[:style]}"}])

    actual = ([1]*2).map do |x|
      composed.call(x)
    end

    assert_array_equal [
      'style: ',
    ]*2, actual
  end

  test 'modifying opts is harmless in compose row function' do
    init_opts = {:key => 'val', :style => 'some style'}
    init_opts_copy = init_opts.dup
    composed = compose_row_function([
        lambda do |x,opts|
          (key,style) = [opts[:key], opts[:style]]
          opts[:key] = "#{opts[:key]} x"
          opts[:style] = "#{opts[:style]} y"
          [key, style]
        end
      ]*2,
      init_opts
    )

    actual = ([1]*4).map do |x|
      composed.call(x)
    end

    # the passed opts were unmodified
    assert_equal init_opts_copy, init_opts

    # the internal opts passed to each invocation also unmodified
    assert_array_equal [
      ['val', 'some style;border-bottom:none!important'],
      ['val', 'some style;border-top:none!important'],
    ]*2, actual
  end
end
