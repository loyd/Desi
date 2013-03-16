BaseViewModel = require 'libs/base_view_model'
Synchronizer  = require 'libs/synchronizer'
countTextSize = require('libs/count_text_size').specify('.member')
ko            = require 'ko'

MIN_GOR_PADDING  = 5  # [unit]
VERT_PADDING     = 3  # [unit]
UNDERLINE_MARGIN = .5 # [unit]

class MemberViewModel extends BaseViewModel
	constructor : (@sync) ->
		@name       = sync.observer 'name'
		@type       = sync.observer 'type'
		@visibility = sync.observer 'visibility'
		@isStatic   = sync.observer 'isStatic'

		@posY  = ko.observable()
		@width = ko.observable()

		super

	height   : countTextSize('A').height + VERT_PADDING * 2
	textPosX : MIN_GOR_PADDING
	textPosY : @::height - MIN_GOR_PADDING

	separatorLinePosX1 : MIN_GOR_PADDING / 2
	@computed \
	separatorLinePosX2 : ->
		@width() - MIN_GOR_PADDING / 2

	@computed \
	minWidth : ->
		countTextSize(@text()).width + MIN_GOR_PADDING * 2

	@computed \
	underlinePosX1 : ->
		countTextSize(@visibility()).width

	@computed \
	underlinePosX2 : ->
		@minWidth() - MIN_GOR_PADDING

	underlinePosY : @::height - VERT_PADDING + UNDERLINE_MARGIN

class AttributeViewModel extends MemberViewModel
	constructor : (@sync) ->
		@textElement = ko.observable null

		super

	@computed \
	text : ->
		"#{@visibility()} #{@name()} : #{@type()}"

class OperationViewModel extends MemberViewModel
	constructor : (@sync) ->
		@params = sync.observer 'params',
			classAdapter : ParamViewModel

		@paramsAreOpen = ko.observable no

		super

	addParam : ->
		sync  = new Synchronizer @spec.data.params.item
		param = new ParamViewModel sync
		@params.push param

	removeParam : (param) ->
		@params.delete param

	@computed \
	paramsText : ->
		@params().reduce((res, param) ->
			res + param.text() + ', '
		, '')[...-2]

	@computed \
	text : ->
		str = "#{@visibility()} #{@name()}(#{@paramsText()})"
		if @type() != 'void'
			str += " : #{@type()}"
		str

class ParamViewModel extends BaseViewModel
	constructor : (@sync) ->
		@name = sync.observer 'name'
		@type = sync.observer 'type'

		super

	@computed \
	text : ->
		"#{@name()} : #{@type()}"

module.exports = { AttributeViewModel, OperationViewModel }