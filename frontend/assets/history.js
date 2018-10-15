(function(exports) {

    function ASHistory() {
        this.setUpHistory();
    };

    ASHistory.prototype.updateDiffButtons = function(on_button) {
	$('.as-history-tb-diff-button-group').children('a').css('background', 'initial');
        $('#' + on_button).css('background', '#eee');
    };

    ASHistory.prototype.showDiffOnlyClick = function() {
	$('.history-diff-field').slideUp();
	$('.history-clean-field').slideUp();
	$('.history-change').slideDown();
        this.updateDiffButtons('as-history-tb-diff-only-button');
    };

    ASHistory.prototype.showDiffAllClick = function() {
	$('.history-diff-field').slideUp();
	$('.history-clean-field').slideDown();
	$('.history-change').slideDown();
        this.updateDiffButtons('as-history-tb-diff-all-button');
    };

    ASHistory.prototype.showDiffCleanClick = function() {
	$('.history-diff-field').slideDown();
	$('.history-clean-field').slideDown();
	$('.history-change').slideUp();
        this.updateDiffButtons('as-history-tb-diff-clean-button');
    };

    ASHistory.prototype.setUpHistory = function() {
	this.showDiffAllClick();
    };

    exports.ASHistory = ASHistory;

}(window));
