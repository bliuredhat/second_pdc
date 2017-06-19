(function($) {
//= require jquery
//

window.form_toggle = function(elem, display) {
  var container = $(elem).closest('.inline_form_container');

  if (display === undefined) {
    // One is hidden the other is visible. Flip them both.
    container.find('.hidden_form').toggle();
    container.find('.display_form').toggle();
  } else {
    // This looks weird because the class names are poor, but it's right:
    // form_toggle(elem, true) -> display the form
    // form_toggle(elem, false) -> don't display the form
    // The assumption is that the element with .hidden_form (the one which is
    // hidden when the page is loaded initially) is the form.
    container.find('.hidden_form').toggle(display);
    container.find('.display_form').toggle(!display);
  }
};

window.form_toggle_all = function(within, display) {
  $('.display_form', within).each(function(idx,e) {
    form_toggle(e, display);
  });
};

/*
  Hooks for inline data-remote forms with spinners and error display.

  If you add the et-ajax-form class to a form, you get the additional
  behavior:

    - inputs are disabled while the form is submitting
    - any .wait-spinner is shown while the form is submitting
    - .et-ajax-form-error is shown on submission error
    - .et-ajax-form-error-text has error text inserted on submission error
*/
$(document).on('ajax:error', '.et-ajax-form', function(evt,xhr) {
  var form = $(evt.target),
    str = et_xhr_error_to_string(xhr);
  $('.et-ajax-form-error-text', form).text(str);
  $('.et-ajax-form-error', form).show();
});

$(document).on('ajax:beforeSend', '.et-ajax-form', function(evt){
  var form = $(evt.target);
  $('.et-ajax-form-error', form).hide();
  $('.et-ajax-form-error-text', form).text('');
  $('.wait-spinner', form).show();
  $('input', form).attr('disabled', true);
});

$(document).on('ajax:complete', '.et-ajax-form', function(evt){
  var form = $(evt.target);
  $('.wait-spinner', form).hide();
  $('input', form).attr('disabled', false);
});

// firefox remembers the 'disabled' attribute over a refresh,
// so we explicitly initialize to enabled to clear that
$(function(){
  $('.et-ajax-form').find('input').attr('disabled', false);
});

}(jQuery));
