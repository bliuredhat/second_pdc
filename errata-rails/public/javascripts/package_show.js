(function($) {

  // Using JS only to show/hide the form. The form is plain old non-Ajax.
  function exclusion_form_toggle(event) {
    event.preventDefault();
    var container = $(this).closest('.excl_container');
    // One is hidden the other is visible. Flip them both.
    container.find('.exclusion_form').toggle();
    container.find('.show_ex_form').toggle();
    container.find(':text:visible').focus();
  }

  $(function() {
    $('.excl_container').find('.btn-toggle').on('click', exclusion_form_toggle);
  });

}(jQuery));
