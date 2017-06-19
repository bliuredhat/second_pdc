(function($) {
/*
 * When you uncheck one of the push types, this will hide the options for it
 * Also hides the submit button if none of them are checked.
 */

window.toggle_options = function(check_box) {
  $(check_box).closest('.push_container').find('.indent').eq(0).toggle(check_box.checked);

  // Hide the submit button if none are checked.
  $('#submit_button').toggle($('.push_check_box').is(':checked'));
};

  $(function() {
    // hack for firefox
    $('.push_check_box').each(function(){ toggle_options(this); });
  });

}(jQuery));
