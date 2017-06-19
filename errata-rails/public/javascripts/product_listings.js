(function($){

  var debug_checkbox = 'input[name="rp[debug]"]',
    debug_spinner = '#product-listings-debug-spinner',
    debug_error = '.product-listings-debug-error',
    pv_select = 'select[name="rp[pv_or_pr_id]"]',
    nvr_input = 'input[name="rp[nvr]"]',
    nvr_timeout,
    debug_ajax;

  function stopDebug() {
    if (debug_ajax) {
      debug_ajax.abort();
      debug_ajax = null;
    }
  }

  function stopNvrTimeout() {
    if (nvr_timeout) {
      window.clearTimeout(nvr_timeout);
    }
  }

  function getProductListingsDebug() {
    stopNvrTimeout();
    stopDebug();

    $(debug_error).hide();
    $(debug_spinner).show();

    debug_ajax = $.ajax('product_listings_prefetch_debug', {
      data: $(debug_checkbox).closest('form').serialize(),
      dataType: 'script'
    }).always(function(){
      debug_ajax = null;
      $(debug_spinner).hide();
    }).fail(function(jqXHR) {
      if (jqXHR.statusCode() === 0) {
        // aborted - not an error
        return;
      }
      $(debug_error).text(
        "Failed to get product listings debug info: " + et_xhr_error_to_string(jqXHR)
      ).show();
    });

    return debug_ajax;
  }

  $(document).on('change', debug_checkbox, function(){
    var elem = $('#product-listings-prefetch-debug');
    if (!this.checked) {
      elem.hide();
      $(debug_error).hide();
      stopDebug();
    } else {
      getProductListingsDebug().done(function(){
        elem.show();
      });
    }
  });

  $(document).on('change', pv_select, function(){
    $(debug_checkbox).change();
  });

  $(document).on('input', nvr_input, function(){
    stopNvrTimeout();
    nvr_timeout = window.setTimeout(function(){
      $(debug_checkbox).change();
    }, 400);
  });

})(jQuery);
