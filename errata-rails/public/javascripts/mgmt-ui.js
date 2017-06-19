
;(function($){

var mUI = window.mUI = {

  getContainer: function(elem) {
    return $(elem).closest('.mgmt');
  },

  formBehaviours: {
    selectWithTextUpdate: function(elem) {
      var parentTd = $(elem).closest('td');
      parentTd.find('.select-text').hide();
      parentTd.find('.select-text-'+elem.value).show();
    },

    showHidePushTargets: function(elem) {
      var parentTable = $(elem).closest('table');
      var externalTargets = parentTable.find('.external_true');
      var cdwFlagPrefix = parentTable.find('input.cdw_flag_prefix_input');
      if (elem.checked) {
        externalTargets.attr('checked', false).attr('disabled', true);
        externalTargets.closest('div').addClass('disabled');
        cdwFlagPrefix.closest('tr').show();
      }
      else {
        externalTargets.attr('disabled', false);
        externalTargets.closest('div').removeClass('disabled');
        cdwFlagPrefix.val('').closest('tr').hide();
      }
    }
  },

  utils: {
    // http://remysharp.com/2010/07/21/throttling-function-calls/
    // (also in defined charcount.js, todo DRY it up)
    throttle: function(fn, delay) {
      var timer = null;
      if (!delay) delay = 100;
      return function () {
        var context = this, args = arguments;
        clearTimeout(timer);
        timer = setTimeout(function(){
          fn.apply(context, args);
        }, delay);
      };
    }
  },

  tableFilter: function(){
    var container = $(this).closest('.mgmt-main');
    var filter = $.trim(container.find('.filter_input').val().toLowerCase());
    var showInactive = container.find('.show_inactive_checkbox').is(':checked');

    var shownCount = 0;
    var allCount = 0;

    // Hide/show table rows
    container.find('table tr').each(function(){
      allCount += 1;
      var foundMatch = false;
      // check for search match
      $(this).find('.filter_on').each(function(){
        var text = $(this).text().toLowerCase();
        if (text.indexOf(filter) != -1)
          foundMatch = true;
      });
      // strip inactives maybe
      if (!showInactive && $(this).hasClass('is_inactive')) {
        foundMatch = false;
        allCount -= 1; // hmm...
      }
      // hide/show the table row
      $(this).toggle(foundMatch);

      // count matches
      if (foundMatch) shownCount += 1;

      // dynamic stripes
      $(this).removeClass('bz_odd');
      if (shownCount % 2 == 1) $(this).addClass('bz_odd');
    });

    var quick_filter = container.find('.quick_filter');
    var newMessage;
    if (shownCount === 0) {
      newMessage = "No matches";
      quick_filter.removeClass('inactive');
    }
    else if (shownCount === allCount && filter === "") {
      newMessage = "("+allCount+")";
      quick_filter.addClass('inactive');
    }
    else {
      newMessage = ""+shownCount+" of "+allCount + " shown";
      quick_filter.removeClass('inactive');
    }
    quick_filter.find('.shown_indicator').html(newMessage);
  },

  triggerRefreshes: function(container) {
    if (container) {
      container.find('select.select-with-text').change();
      container.find('input.internal-check').change();
    }
    else {
      // do all
      $('select.select-with-text').change();
      $('input.internal-check').change();
    }
  },

  initBehaviours: function() {
    // A select with some text below it. When the select changes the text changes correspondingly.
    $('select.select-with-text').change(function(){ mUI.formBehaviours.selectWithTextUpdate(this); });

    // When internal product is checked have to hide/disable some push targets
    $('input.internal-check').change(function(){ mUI.formBehaviours.showHidePushTargets(this); });

    // Make the quick filter work
    $('.mgmt .quick_filter .show_inactive_checkbox').
      change(mUI.tableFilter).
      attr('checked', false);

    $('.mgmt .quick_filter .filter_input').
      focus(mUI.tableFilter).
      blur(mUI.tableFilter).
      keyup(mUI.utils.throttle(mUI.tableFilter)).
      // make sure it starts in correct state
      blur();

    // for clearing the filter
    $('.mgmt .quick_filter a').click(function(){
      $(this).closest('.quick_filter').find('.filter_input').val('').keyup();
      return false;
    });

  },

  setup: function() {
    mUI.initBehaviours();
    mUI.triggerRefreshes();

    // Need to use setTimeout to make focus() work in FF.
    // Chrome and Safari works fine without set timeout.
    setTimeout(function() {
      $('.mgmt .quick_filter .filter_input').focus();
    },500);
  }
};

$(document).ready(mUI.setup);

})(jQuery);
