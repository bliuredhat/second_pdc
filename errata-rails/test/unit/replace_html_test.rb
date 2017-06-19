require 'test_helper'

class ReplaceHtmlTest < ActiveSupport::TestCase
  # Need to include this to call helper_method
  include ActionController::Helpers
  include ReplaceHtml

  # Mock output of render_to_string (:partial only)

  def setup
    @template_renders = {
      :simple => '<p>some rendered template</p>',
      :strippable => ' <p>some rendered template</p>   ',
      :with_nl => "some\nrendered\r\ntemplate\rmixed\nnewlines",
      :mixed => <<-eos
  <div class="dquotes" id='squotes'>
Here's some text.
</div>
  eos
    }
  end

  def render_to_string(render_opts)
    name = render_opts[:partial]
    assert_not_nil(name, 'only :partial is mocked')
    @template_renders[name] || "(unexpected template #{name})"
  end

  # for escape_javascript
  include ActionView::Helpers::JavaScriptHelper
  def view_context
    self
  end

  test "js_for_html" do
    js = js_for_html('foo', '<h1>test</h1>')
    assert_match(/#foo'\)/, js)
    assert_match(/\.html\(/, js)

    assert_match(/\.replaceWith\(/, js_for_html('foo', 'bar', 'replaceWith'))
  end

  test "partial_to_string" do
    [
      [:simple, false, @template_renders[:simple]],
      [:simple, true, @template_renders[:simple]],

      # leading/trailing whitespace always stripped
      [:strippable, false, '<p>some rendered template</p>'],
      [:strippable, true, '<p>some rendered template</p>'],

      [:with_nl, false, @template_renders[:with_nl]],
      [:with_nl, true, 'some\nrendered\ntemplate\nmixed\nnewlines'],

      [:mixed, false, @template_renders[:mixed].strip],
      [:mixed, true, '<div class="dquotes" id=\'squotes\'>\nHere\'s some text.\n</div>'],
    ].each do |template, escape, expected_out|
      processed = partial_to_string(template, {}, escape)
      assert_equal(expected_out, processed, "incorrect result for template #{template}, escape #{escape}")
    end
  end

  test "js_for_template" do
    assert_equal(<<-'eos'.chomp, js_for_template( 'someid', :simple))
$('#someid').html('<p>some rendered template<\/p>');Eso.initAll('#someid');
    eos

    assert_equal(<<-'eos'.chomp, js_for_template( 'someid', :mixed, {}, 'replaceWith'))
$('#someid').replaceWith('<div class=\"dquotes\" id=\'squotes\'>\nHere\'s some text.\n<\/div>');Eso.initAll('#someid');
    eos
  end

  test 'js_set_val' do
    assert_equal "$('#foo').val('');",
                 js_set_val('foo', nil);
    assert_equal "$('#foo').val('Hello,\\n\\\"world\\'');",
                 js_set_val('foo', "Hello,\n\"world'");
  end
end

