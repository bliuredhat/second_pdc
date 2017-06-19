/*
 Allow to go straight to a particular tab by specifying an anchor follow by the tab name
 in the request url.
*/
(function($) {
  $(function() {
    // show the specified tab on page load
    var href_val = window.location.hash || undefined;
    if (href_val) {
      $("#object_tab li." + href_val.replace(/#/,'')).find("a[data-toggle='tab']").tab('show');
    }
  });
}(jQuery));