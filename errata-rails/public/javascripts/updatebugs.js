(function($){

  // Used in a/v/bugs/updatebugstates in select onchange to show/hide a textarea
  window.show_bug_comment = function(objectId, currentStatus, selectElem) {
    $('#' + objectId + "_comment").toggle("" !== selectElem.value);
    return true;
  };

  $(document).ready(function(){
    $('.bug_status_select').on('change', function() {
      var $this = $(this);
      show_bug_comment($this.data('areaid'), $this.data('bugstatus'), this);
    });
    // Avoid inconsistency when browser preserves dropdown state
    $('.bug_status_select').change();
  });

})(jQuery);
