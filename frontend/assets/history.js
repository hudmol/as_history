(function(exports) {

    function ASHistory() {
        this.setUpHistory();
    };

    ASHistory.prototype.updateDiffButtons = function(on_button) {
	      $('.as-history-tb-diff-button-group').children('a').css('background', 'initial');
        $('#' + on_button).css('background', '#ddd');
    };

    ASHistory.prototype.setDiffMode = function(mode) {
        if (mode == 'only') {
            $('.history-raw-view').slideUp();
            $('.history-diff-field').slideUp();
            $('.history-clean-field').slideUp();
            $('.history-change').slideDown();
        } else if (mode == 'clean') {
            $('.history-raw-view').slideUp();
            $('.history-diff-field').slideDown();
            $('.history-clean-field').slideDown();
            $('.history-change').slideUp();
        } else if (mode == 'raw') {
            $('.history-diff-field').slideUp();
            $('.history-clean-field').slideUp();
            $('.history-change').slideUp();
            $('.history-raw-view').slideDown();
        } else { // 'all'
            $('.history-raw-view').slideUp();
            $('.history-diff-field').slideUp();
            $('.history-clean-field').slideDown();
            $('.history-change').slideDown();
            mode = 'all';
        }

        this.updateDiffButtons('as-history-tb-diff-' + mode + '-button');
        localStorage.setItem('as_history_show_diff_mode', mode);
    };

    ASHistory.prototype.showDiffOnlyClick = function() {
        this.setDiffMode('only');
    };

    ASHistory.prototype.showDiffAllClick = function() {
        this.setDiffMode('all');
    };

    ASHistory.prototype.showDiffCleanClick = function() {
        this.setDiffMode('clean');
    };

    ASHistory.prototype.showDiffRawClick = function() {
        this.setDiffMode('raw');
    };

    ASHistory.prototype.updateBrowseButton = function() {
	var label = '';
        var uri = '/history';
	var qs = {};
	label = 'Recent updates';
        if (!$('select[name=model]').is(':disabled')) {
  	    var selected_model = $('select[name=model]').find('option:selected').attr('value');
	    if (selected_model == '_all') {
	    } else {
	        uri += '/' + selected_model;
	        if ($('input[name=id]').is(':disabled') || $('input[name=id]').val() == '') {
		    label = 'Recent updates to ' + selected_model + ' records';
	        } else {
		    label = 'Revision history for ' + selected_model + ' / ' + $('input[name=id]').val();
		    uri += '/' + $('input[name=id]').val();
	        }
	    }
	}

	if (!$('input[name=user]').is(':disabled') && $('input[name=user]').val() != '') {
	    label += ' by ' + $('input[name=user]').val();
	    qs['user'] = $('input[name=user]').val();
	}

	if (!$('input[name=time]').is(':disabled') && $('input[name=time]').val() != '') {
	    label += ' at ' + $('input[name=time]').val();
	    qs['time'] = $('input[name=time]').val();
	}

	$('.history-version-set-label').html(label);
	if (!jQuery.isEmptyObject(qs)) {
	    uri += '?';
	    $.each(qs, function(k,v) {
		uri += k + '=' + v + '&';
	    });
	    uri = uri.substring(0, uri.length-1);
	}
	$('.history-version-set-button').attr('href', uri);
    };

    ASHistory.prototype.setUpHistory = function() {
	this.setDiffMode(localStorage.getItem('as_history_show_diff_mode'));
	if (ASHISTORY_USER) {
	    $('#as-history-tb-user-button').css('background', '#ddd');
	}
        if (ASHISTORY_ID && !isNaN(ASHISTORY_DIFF)) {
	    $('.history-version-box').each(function() {
		    var version = parseInt($(this).data('version'));
		    if (version < ASHISTORY_VERSION) {
			if (version == ASHISTORY_DIFF) {
			    $(this).children().addClass('history-showing-diff-version');
			} else if (version > ASHISTORY_DIFF) {
			    $(this).children().addClass('history-showing-diff-included-version');
			}
		    }
	    });
	}

	// set up browse history
	var locor = location.origin;
	//localStorage.removeItem('as_history_browse_history');

	if ((browse_history_string = localStorage.getItem('as_history_browse_history'))) {
	    browse_history = JSON.parse(browse_history_string);
	    if (!(locor in browse_history)) {
		browse_history[locor] = [];
	    }
	} else {
	    browse_history = {
		[locor]: []
	    };
	}

	var remove_ix = [];
	var browse_uri = location.pathname;
	browse_uri = browse_uri.replace(/(\/\d+)\/\d+$/, '$1');
	browse_uri += location.search.replace(/\?diff=\d+$/, '');

	$(browse_history[locor]).each(function(ix) {
		var browse_item = this;
		if (browse_item['uri'] == browse_uri) {
		    remove_ix.unshift(ix);
		    return;
		}
		var new_button = $('#history-previous-version-set-template').clone();
		new_button.removeAttr('id');
		new_button.attr('href', browse_item['uri']);
		new_button.html(browse_item['label']);
		new_button.css('display', 'inline-block');
		new_button.appendTo('.history-previous-sets-pane');
	    });

        $(remove_ix).each(function(ix) {
	    browse_history[locor].splice(this,1);
	});

	browse_history[locor].unshift({uri: browse_uri, label: $('.history-version-set').first().text()});
	browse_history[locor] = browse_history[locor].slice(0,10);

	localStorage.setItem('as_history_browse_history', JSON.stringify(browse_history));


	$('.history-control').on('change keyup paste', function() {
	    as_history.updateBrowseButton();
	});

	$('.history-axis-select input[type=checkbox]').on('change', function(e) {
	    $(this).next().prop('disabled', !$(this).is(':checked'));

	    if ($(this).next().attr('name') == 'model' && $(this).next().is(':disabled')) {
		$('.history-axis-id input[type=checkbox]').prop('checked', false);
		$('.history-axis-id input[name=id]').prop('disabled', true);
	    }

	    if ($(this).next().attr('name') == 'id' && !$(this).next().is(':disabled')) {
		$('.history-axis-model input[type=checkbox]').prop('checked', true);
		$('.history-axis-model select[name=model]').prop('disabled', false);
	    }

	    as_history.updateBrowseButton();
	});

	this.updateBrowseButton();

    };

    exports.ASHistory = ASHistory;

}(window));
