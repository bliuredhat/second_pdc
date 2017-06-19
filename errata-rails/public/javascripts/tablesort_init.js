(function($) {

  $(document).ready(function() {
    $('table.tablesorter').tablesorter({
      widgets: ["zebra"],
      widgetOptions : { zebra : [ "bz_even", "bz_odd" ] }
    });

  });

}(jQuery));