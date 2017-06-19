
;(function($){

$(document).ready(function(){
  $('.require_at_least_one_checkbox').find(':checkbox').click(function(){
    var clicked = $(this);
    // See if there at least one checkbox still checked
    var container = clicked.closest('.require_at_least_one_checkbox');
    if (!container.find(':checked').length) {
      // If there are none left then we turn this checkbox back on.
      // Have to have at least one checked...
      this.checked = true;
      clicked.closest('label').addClass('selected');
    }
    else {
      clicked.closest('label').toggleClass('selected',this.checked);
    }
  });

  // Make sure the highlighting doesn't start out of sync
  $('.require_at_least_one_checkbox').find(':checkbox').each(function(){
    $(this).closest('label').toggleClass('selected',this.checked);
  });

  // Handy links to select all
  $('.check_box_select_all').click(function(){
    // td container is stupid and non-generic.. but only using this in one place... worry about it later
    $(this).closest('td').find('.require_at_least_one_checkbox').find(':checkbox').each(function(){
      this.checked = true;
      $(this).closest('label').addClass('selected');
    });
    return false;
  });

  // Handy link to select active states..
  $('.check_box_select_active').click(function(){
    $(this).closest('td').find('.require_at_least_one_checkbox').find(':checkbox').each(function(){
      if (this.id.match(/NEW_FILES|QE|REL_PREP|PUSH_READY/)) {
        this.checked = true;
        $(this).closest('label').addClass('selected');
      }
      else {
        this.checked = false;
        $(this).closest('label').removeClass('selected');
      }
    });
    return false;
  });

});


})(jQuery);
