(function($){

    //
    // This was previously done using some RJS in ErrataController#type_change
    // I needed to add some behaviour based on the is_text_only so
    // decided to redo it as client side only. See bug 740819.
    //
    function show_hide_rhsa_fields_and_cpe_text_only() {

      var vars_element = $('input#js-vars');
      var is_secalert = vars_element.data('is-secalert');
      var is_persisted_rhsa = vars_element.data('is-persisted-rhsa');
      var is_persisted_embargo_date = vars_element.data('is-persisted-embargo-date');

      // Check the applicable radio buttons and checkboxes
      var is_selected_sa = $('#advisory_errata_type_rhsa').is(':checked') || $('#advisory_errata_type').val() == 'RHSA' ||
        $('#advisory_errata_type_pdcrhsa').is(':checked') || $('#advisory_errata_type').val() == 'PdcRHSA';
      var is_text_only = $('#advisory_text_only').is(':checked');

      // Show or hide the fields as required.
      // The targets here are tr elements so the labels are hidden also.
      // (jQuery toggle can take a boolean argument meaning 'show if true').
      $('#security_impact, #cve_names').toggle(is_selected_sa);
      $('#cpe_text, #product_version_text').toggle(is_text_only && is_selected_sa);

      var show_embargo_date, enable_embargo_date;
      if (is_secalert || (!is_persisted_rhsa && !is_selected_sa)) {
        show_embargo_date = true;
        enable_embargo_date = true;
      } else if ((!is_persisted_rhsa && is_selected_sa) || (is_persisted_rhsa && !is_persisted_embargo_date)) {
        show_embargo_date = false;
      } else {
        show_embargo_date = true;
        enable_embargo_date = false;
      }
      enable_embargo_date = enable_embargo_date && show_embargo_date;

      $('#embargo_date input').each(function(i,elem) {
        $(elem).attr('disabled', !enable_embargo_date);
      });
      $('.embargo_date_enabled_text' ).toggle(enable_embargo_date);
      $('.embargo_date_disabled_text').toggle(!enable_embargo_date);
      $('#embargo_date'              ).toggle(show_embargo_date);
      $('#embargo_date_hidden'       ).toggle(!show_embargo_date);
    }

  function onCloneSubmit(event) {
    event.preventDefault();

    var cloneId = $('#clone-input').val();

    $.ajax({
      url: 'clone_errata',
      datatype: 'script',
      data: {id: cloneId.trim(), format: 'js'},
      beforeSend: function() {
        $('.clone-button').removeClass('show-error');
        $('.manual-clone').addClass('show-process');
        $('.clone-error').find('span').text('');
      },
      error: function(xhr) {
        var str = et_xhr_error_to_string(xhr);
        $('.clone-error').find('span').text(str);
        $('.clone-button').addClass('show-error');
      },
      success: function() {
        $('.manual-clone').addClass('show-success');
        initEditForm();
      },
      complete: function() {
        $('.manual-clone').removeClass('show-process');
      }
    });
  }

  function monitorScroll() {
    var previewButton = $('.preview-button');
    var isDown = $(document).scrollTop() + $(window).height() - $('body')[0].scrollHeight + $('#eso-footer').height() > 0 ? true : false;
    var isAbove = previewButton.is('.above-doc-footer');
    if (isDown && !isAbove) {
      $('#eso-content').css({ 'position': 'relative' });
      previewButton.addClass('above-doc-footer');
    } else if (!isDown && isAbove) {
      $('#eso-content').css({ 'position': '' });
      previewButton.removeClass('above-doc-footer');
    }
  }

  function cloneFromClicked() {
    var manualClone = $(this).parent();
    if (manualClone.is('.show-success')) {
      manualClone.removeClass('show-success')
        .find('.current-clone').remove();
    }
    if (manualClone.is('.show-error')) {
      manualClone.removeClass('show-error');
    }
    manualClone.toggleClass('show');
    $('#clone-input').val('').focus();
  }

  function cloneInputEdited(event) {
    var $this = $(this);
    if ($.trim( $this.val() ).length != 0 ){
      $this.parent().addClass('clone-button');
    } else {
      $this.parent().removeClass('clone-button show-error');
    }
  }

  function cloneInputKeyPressed(event) {
    // If user pressed enter, normally it would attempt to submit the containing
    // form.  We don't want that, since that's the advisory create/edit form.
    // Instead we want to active the clone-submit button.
    if (event.keyCode === 13) {
      onCloneSubmit(event);
    }
  }

  function errorFieldEdited(event) {
    var target = $(event.target),
        parent = target.closest('.field_with_errors').parent(),
        initialVal = target.data('initial-val'),
        val = target.val();

    // If this is the first time the target is being edited, store the current
    // value, so we can remove "edited" if the field is returned to its original
    // state.
    if (initialVal === undefined) {
      target.data('initial-val', val);
    }

    if (val !== initialVal) {
      parent.addClass('edited');
    } else {
      parent.removeClass('edited');
    }
  }

  // On page load, if there's any field with errors, focus it and do an animated
  // scroll down to it to bring it to the user's attention.
  function navigateToErrorField() {
    var field = $('.field_with_errors').first();
    if (!field.length) {
      return;
    }

    var input   = $('input, textarea', field).first(),
        focus   = input ? input.focus.bind(input) : function(){},
        top     = field.get(0).getBoundingClientRect().top + window.scrollY,
        animate = function() {
          // Note: html for firefox, body for webkit/chrome
          $('html, body').animate({scrollTop: top - 10}, 1200, focus);
        };

    // Delay a bit before starting the animation, hopefully less confusing
    window.setTimeout(animate, 500);
  }

  function initEditForm() {
    makeItCount('advisory_description', 4000, false);

    // Whenever the type radio buttons and the text only checkbox are changed
    // want to run the above method to show/hide fields.
    $('#advisory_text_only, #advisory_errata_type_rhba, #advisory_errata_type_rhea, #advisory_errata_type_rhsa,' +
      '#advisory_errata_type_pdcrhba ,#advisory_errata_type_pdcrhea, #advisory_errata_type_pdcrhsa').click(show_hide_rhsa_fields_and_cpe_text_only);

    // Ensure we start in correct state.
    // (Deals with edge case where a non-secalert user clones from an RHSA).
    show_hide_rhsa_fields_and_cpe_text_only();

    $(document).on('scroll', monitorScroll);
    $(document).on('keydown input', '.field_with_errors *', errorFieldEdited);

    $('a.clone-submit').click(onCloneSubmit);
    $('.clonefrom').click(cloneFromClicked);
    $('#clone-input').
      on('keyup', cloneInputEdited).
      on('keypress', cloneInputKeyPressed).
      blur(cloneInputEdited);

    navigateToErrorField();
  }

  $(document).ready(initEditForm);

})(jQuery);
