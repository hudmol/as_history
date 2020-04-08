// in_a_rush key bindings
$(function() {

  if (typeof InARush !== 'undefined') {

    var translate = function(s) {
      return (HISTORY_IN_A_RUSH_TRANSLATIONS[s] || s);
    };

    InARush.Bindings.addBinding({
      id: 'system_history',
      keySequence: ['h'],
      handler: function () { window.location.href = APP_PATH + 'history'; },
      description: translate('system_history'),
      condition: function () { return !window.location.href.includes('/history'); },
      category: translate('category_history'),
    });

    InARush.Bindings.addBinding({
      id: 'record_history',
      keySequence: ['r'],
      handler: function () {
		window.location.href = $('#as-history-button').attr('href');
	       },
      description: translate('record_history'),
      condition: function () { return $('#as-history-button').length > 0; },
      category: translate('category_history'),
    });

    InARush.Bindings.addBinding({
      id: 'diff_only_history',
      keySequence: ['1'],
      handler: function () {
		$('#as-history-tb-diff-only-button').click();
	       },
      description: translate('diff_only_history'),
      condition: function () { return $('#as-history-tb-diff-only-button').length > 0; },
      category: translate('category_history'),
    });

    InARush.Bindings.addBinding({
      id: 'diff_all_history',
      keySequence: ['2'],
      handler: function () {
		$('#as-history-tb-diff-all-button').click();
	       },
      description: translate('diff_all_history'),
      condition: function () { return $('#as-history-tb-diff-all-button').length > 0; },
      category: translate('category_history'),
    });

    InARush.Bindings.addBinding({
      id: 'diff_clean_history',
      keySequence: ['3'],
      handler: function () {
		$('#as-history-tb-diff-clean-button').click();
	       },
      description: translate('diff_clean_history'),
      condition: function () { return $('#as-history-tb-diff-clean-button').length > 0; },
      category: translate('category_history'),
    });

    InARush.Bindings.addBinding({
      id: 'diff_raw_history',
      keySequence: ['4'],
      handler: function () {
		$('#as-history-tb-diff-raw-button').click();
	       },
      description: translate('diff_raw_history'),
      condition: function () { return $('#as-history-tb-diff-raw-button').length > 0; },
      category: translate('category_history'),
    });

    InARush.Bindings.addBinding({
      id: 'record_audit_history',
      keySequence: ['5'],
      handler: function () {
		$('#as-history-tb-record-button').click();
	       },
      description: translate('record_audit_history'),
      condition: function () { return $('#as-history-tb-record-button').length > 0; },
      category: translate('category_history'),
    });

    InARush.Bindings.addBinding({
      id: 'exit_history',
      keySequence: ['6'],
      handler: function () {
		window.location.href = $('#as-history-tb-exit-button').attr('href');
	       },
      description: translate('exit_history'),
      condition: function () { return $('#as-history-tb-exit-button').length > 0; },
      category: translate('category_history'),
    });

    InARush.Bindings.addBinding({
      id: 'restore_history',
      keySequence: ['7'],
      handler: function () {
		$('#as-history-tb-restore-button').click();
	       },
      description: translate('restore_history'),
      condition: function () { return $('#as-history-tb-restore-button').length > 0; },
      category: translate('category_history'),
    });

    InARush.Bindings.addBinding({
      id: 'quit_history',
      keySequence: ['q'],
      handler: function () {
		window.location.href = $('#as-history-tb-exit-button').attr('href');
	       },
      description: translate('quit_history'),
      condition: function () { return $('#as-history-tb-exit-button').length > 0; },
      category: translate('category_history'),
    });

    InARush.Bindings.addBinding({
      id: 'previous_history',
      keySequence: ['p'],
      handler: function () {
		$('.history-previous-sets-button').click();
	       },
      description: translate('previous_history'),
      condition: function () { return $('.history-previous-sets-button').length > 0; },
      category: translate('category_history'),
    });

    InARush.Bindings.addBinding({
      id: 'search_history',
      keySequence: ['s'],
      handler: function () {
		$('.history-version-set').click();
	       },
      description: translate('search_history'),
      condition: function () { return $('.history-version-set').length > 0; },
      category: translate('category_history'),
    });

    InARush.Bindings.addBinding({
      id: 'goto_diff_history',
      keySequence: [']'],
      handler: function () {
		window.location.href = $('.history-showing-diff-version').attr('href');
	       },
      description: translate('goto_diff_history'),
      condition: function () { return $('.history-showing-diff-version').length > 0; },
      category: translate('category_history'),
    });

    InARush.Bindings.addBinding({
      id: 'goto_newer_history',
      keySequence: ['['],
      handler: function () {
		window.location.href = $('.history-showing-version').parent().prev().children().attr('href');
	       },
      description: translate('goto_newer_history'),
		condition: function () { return $('.history-showing-version').parent().prev().children().length > 0; },
      category: translate('category_history'),
    });

    InARush.Bindings.addBinding({
      id: 'goto_first_history',
      keySequence: ['\\'],
      handler: function () {
		window.location.href = $('.history-version-box').first().children().attr('href');
	       },
      description: translate('goto_first_history'),
		condition: function () { return $('.history-version-box').length > 0; },
      category: translate('category_history'),
    });

    InARush.Bindings.addBinding({
      id: 'goto_last_history',
      keySequence: ["'"],
      handler: function () {
		window.location.href = $('.history-version-box').last().find('.history-version').attr('href');
	       },
      description: translate('goto_last_history'),
		condition: function () { return $('.history-version-box').length > 0; },
      category: translate('category_history'),
    });

  }

});
