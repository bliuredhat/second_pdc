(function($) {

$(function(){
  // Read "Loading..." message from static html
  var loadingIndicatorContent = $('.quick-action-menu .dropdown-menu').first().html();

  function errorIndicatorContent(msg) {
    return '<li><span class="not-loaded red">' + $.trim(msg) + '!</span></li>';
  }

  // When quick action menu button is clicked
  $('.quick-action-menu a.dropdown-toggle').click(function(){
    // Locate the drop down menu container
    var $dropdownMenu = $(this).find('~ .dropdown-menu');
    // Check if the menu content isn't already loaded
    // (Assumes the loading text element is initially present)
    if ($dropdownMenu.find('.not-loaded').length) {
      // Locate the relevant errata id
      var errataId = $(this).closest('.errata_row').data('errata-id');
      // Show the loading message
      // (Needed for the case where we got an error previously and are trying again)
      $dropdownMenu.html(loadingIndicatorContent);
      // Fetch and load menu content
      $dropdownMenu.load("/errata/ajax_quick_action_menu_links/" + errataId, function(resp, respStatus, xhr){
        // Show error if there's a problem
        if (respStatus == 'error') { $dropdownMenu.html(errorIndicatorContent(et_xhr_error_to_string(xhr))); }
      });
    }
  });

});

}(jQuery));
