(function($) {

$(function(){
  //
  // Hack so the entire advisory row is clickable, but any actual links inside the container work as normal.
  // (.errata_row is for the new standard output format and .errata_list_single tr is for the old style output formats)
  // Todo: should use clickable_row and clickable_row_link for all these instead of having three different ways to use it.
  //
  $('.errata_row, .errata_list_single tr, .clickable_row').click(function(e){
    // If a real link was clicked then let the link do whatever it would normally do
    if (e.target.nodeName === 'A') return true;

    // Prevent unexpected behaviour in the bootstrap quick action menu
    if ($(e.target).parents('.btn-group').length) return true;

    // See if we can find a link to follow, then follow it
    var advisory_link = $(this).find('.advisory_link, .clickable_row_link');
    if (advisory_link.length) {
      window.location = advisory_link.attr('href');
    }
  });

});

}(jQuery));
