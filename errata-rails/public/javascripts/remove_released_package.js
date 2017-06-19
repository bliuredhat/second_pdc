(function($){

var highlight_row_for_delete = function() {
  $(this).closest('tr').toggleClass('highlight-for-delete', this.checked);
};

window.remove_rel_pkgs_all_checkboxes = function(event) {
  event.preventDefault();
  $('.delete_check_box').find('input').prop('checked', $(this).data('check')).each(highlight_row_for_delete);
};

var package_list_message = function() {
  var max_to_list = 12;
  var checked_boxes = $('.delete_check_box').find('input:checked');
  var len = checked_boxes.length;
  var result = "";

  result += $.map(checked_boxes.slice(0, max_to_list), function(elem){
    return ' - ' + $(elem).closest('tr').find('.released_build_link').text();
  }).join('\n');

  if (len > max_to_list) {
    result += '\n - ...and ' + (len - max_to_list) + ' more';
  }

  return result;
};

$(document).ready(function(){
  $('.delete_check_box').find('input')
    .change(highlight_row_for_delete)
    // ensure we start with correct highlight
    .each(highlight_row_for_delete);

  $('#remove_packages_form').submit(function(){
    var message_text = package_list_message();
    if (message_text === "") {
      alert('No packages selected!');
      return false;
    }
    return confirm('Are you sure you want to remove:\n' + message_text + '\nfrom the list of released packages?');
  });

  $('.btn-check-build').on('click', remove_rel_pkgs_all_checkboxes);

});

})(jQuery);
