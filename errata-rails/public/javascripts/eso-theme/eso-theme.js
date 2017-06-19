;(function($){

//
// Expose our methods via a top level Eso object.
// Rails can call these methods from RJS, eg: page.eso.init_chosen
//
if (!window.Eso) window.Eso = {};
$.extend(window.Eso,{

  // Chosen.js is a library that modifies drop down selects to make them
  // more user friendly and nice looking
  initChosen: function(context) {
    $('.eso-chosen-select', context).chosen({ allow_single_deselect:true, search_contains:true });
  },

  // This is the jQuery UI calendar date picker
  initDatePickers: function(context) {
    $('.eso-datepicker', context).datepicker({ altFormat:'yy-M-dd', dateFormat:'yy-M-dd' });
  },

  initSearchBoxBehaviour: function() {
    $('#topbar-search-form input').focus(function(e){
      $(this).addClass('hasFocus');
    });
    $('#topbar-search-form input').blur(function(e){
      $(this).removeClass('hasFocus');
    });
  },

  initPopovers: function(context) {
    $('a[rel=popover], a.popover-test', context).popover({});
    $('a[rel=tooltip], a.tooltip-test', context).tooltip({});
  },

  initAll: function(context) {
    Eso.initChosen(context);
    Eso.initDatePickers(context);
    Eso.initPopovers(context); // these are bootstrap popovers..

    if (!context) {
      // Search box is in header only
      Eso.initSearchBoxBehaviour();
    }
  }
});

// Initialise all our stuff on document ready
$(document).ready(function(){
  Eso.initAll();
});

})(jQuery);
