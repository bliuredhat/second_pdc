(function($) {

  function fileInputsForType(filetype, form) {
    return $('input[type="checkbox"][data-display-type="' + filetype + '"]', form);
  }
  function globalInputForType(filetype, form) {
    return $('input.file_type_global_toggle[value="' + filetype + '"]', form);
  }

  function setFileInputsFromGlobal() {
    var checked = this.checked,
      $this = $(this),
      filetype = this.value,
      form = $this.closest('form');

    fileInputsForType(filetype, form).each(function(idx,e){
      $(e).prop('checked', checked);
    });
  }

  function setGlobalInputsFromFile(elem) {
    var $elem = $(elem),
      filetype = $elem.data('display-type'),
      form = $elem.closest('form'),
      globalInput = globalInputForType(filetype, form),
      allChecked = fileInputsForType(filetype, form).not(':checked').length === 0,
      allUnchecked = fileInputsForType(filetype, form).filter(':checked').length === 0;

    if (!allChecked && !allUnchecked) {
      globalInput.prop({ "indeterminate": true, "checked": false });
    } else {
      globalInput.prop({ "indeterminate": false, "checked": allChecked });
    }
  }

$(function(){
  $('input.file_type_global_toggle').click(setFileInputsFromGlobal);
  $('input.file_type_toggle').click(function(evt){ setGlobalInputsFromFile(evt.target); });

  // Initially set the global checkboxes based on the per-build checkboxes.
  // Important if the user had some selections on the per-build checkboxes and refreshed.
  $('input.file_type_toggle').each(function(idx,e) {
    setGlobalInputsFromFile(e);
  });
});

}(jQuery));
