BaseViewModel = require 'libs/base_view_model'
countTextSize = require 'libs/count_text_size'
onresize      = require 'libs/onresize'
Synchronizer  = require 'libs/synchronizer'
ko            = require 'ko'

class ClassDiagramViewModel extends BaseViewModel
	viewRoot : '.class-diagram'

	SCALE_DIFF = 0.3

	constructor : (@sync) ->
		@essentials = sync.observer 'essentials',
			classAdapter : EssentialViewModel

		@relationships = sync.observer 'relationships',
			classAdapter : RelationshipViewModel

		@originX     = ko.observable 0
		@originY     = ko.observable 0
		@width       = ko.observable 0
		@height      = ko.observable 0
		@scaleFactor = ko.observable 2
		@element     = ko.observable null

		@editing = no

		onresize '#main', =>
			do @refreshSizes if @editing

		super

	refreshSizes : ->
		style = getComputedStyle(@element(), null)

		@width  parseInt style.width, 10
		@height parseInt style.height, 10

	startEditing : ->
		@editing = yes
		(=> do @refreshSizes).defer()

	stopEditing : ->
		@editing = no

	@computed \
	viewBox : ->
		scaleFactor = @scaleFactor()
		uuWidth  = @width()  / scaleFactor
		uuHeight = @height() / scaleFactor
		"#{@originX()} #{@originY()} #{uuWidth} #{uuHeight}"

	shift : (x, y) ->
		scaleFactor = @scaleFactor()
		@originX @originX() - x / scaleFactor
		@originY @originY() - y / scaleFactor

	scale : (sign) ->
		newFactor = @scaleFactor() + SCALE_DIFF * sign
		@scaleFactor newFactor if newFactor > 0

	@delegate('click') (el, event) ->
		return unless event.target is @element()
		{left, top} = @element().getBoundingClientRect()
		scaleFactor = @scaleFactor()
		x = @originX() + (event.clientX - left) / scaleFactor
		y = @originY() + (event.clientY - top)  / scaleFactor
		@addEssential x, y

	@delegate('mousedown', '.essential') ({posX, posY}, event) ->
		prevX = event.clientX
		prevY = event.clientY

		mouseMove = (e) =>
			scaleFactor = @scaleFactor()
			posX posX() + (e.clientX - prevX) / scaleFactor
			posY posY() + (e.clientY - prevY) / scaleFactor
			prevX = e.clientX
			prevY = e.clientY
			do e.stopPropagation

		mouseUp = (e) ->
			document.removeEventListener 'mousemove', mouseMove, on
			document.removeEventListener 'mouseup', mouseUp, on
			do e.stopPropagation

		document.addEventListener 'mousemove', mouseMove, on
		document.addEventListener 'mouseup', mouseUp, on

		do event.preventDefault

	addEssential : (x, y) ->
		sync = new Synchronizer @spec.data.essentials.item
		ess = new EssentialViewModel sync
		ess.posX x - ess.width() / 2
		ess.posY y - ess.headerHeight() / 2
		@essentials.push ess

class EssentialViewModel extends BaseViewModel
	viewRoot : '.essential'

	MIN_HEADER_PADDING = 10

	constructor : (@sync) ->
		@name = sync.observer 'name'
		@posX = sync.observer 'posX'
		@posY = sync.observer 'posY'

		@attributes = sync.observer 'attributes',
			classAdapter : AttributeViewModel
		@attributes.subscribe => @placeAttributes

		@operations = sync.observer 'operations',
			classAdapter : OperationViewModel
		@operations.subscribe => @placeOperations

		super

	@computed \
	width : ->
		Math.max(
			MIN_HEADER_PADDING * 2 + countTextSize(@name()).width
			(@attributes().map (attr) -> attr.width()).max()
			(@operations().map (oper) -> oper.width()).max()
		)

	@computed \
	height : ->
		@headerHeight() + @attributesHeight() + @operationsHeight()

	@delegate('click', '.btn-add-attribute') \
	addAttribute : ->
		sync = new Synchronizer @spec.attributes.item
		attr = new AttributeViewModel sync
		@attributes.push attr

	@delegate('click', '.btn-rm-attribute') \
	removeAttribute : (attr) ->
		@attributes.remove attr

	@delegate('click', '.btn-add-operation') \
	addOperation : ->
		sync = new Synchronizer @spec.operations.item
		oper = new OperationViewModel sync
		@operations.push oper

	@delegate('click', '.btn-rm-operation') \
	rmOperation : (oper) ->
		@operations.remove oper

	# Header section
	
	headerHeight : ->
		MIN_HEADER_PADDING * 2 + countTextSize(@name()).height

	@computed \
	namePosX : ->
		@width() / 2

	@computed \
	namePosY : ->
		@headerHeight() / 2

	# Attributes section

	attributesHeight : ->
		@attributes().reduce (sum, attr) ->
			sum + attr.height()
		, 0

	placeAttributes : ->
		posY = 0
		for member in @attributes()
			member.posY posY
			posY += member.height()
		return

	@computed \
	attributesPosY : @::headerHeight

	@computed \
	attributesVisible : ->
		@attributes().length

	# Operations section
	
	operationsHeight : ->
		@operations().reduce (sum, oper) ->
			sum + oper.height()
		, 0

	placeOperations : ->
		posY = 0
		for member in @operations()
			member.posY posY
			posY += member.height()
		return

	@computed \
	operationsPosY : ->
		@attributesPosY() + @attributesHeight()

	@computed \
	operationsVisible : ->
		@operations().length
		
class MemberViewModel extends BaseViewModel
	constructor : (@sync) ->
		@posY       = ko.observable()
		@name       = sync.observer 'name'
		@type       = sync.observer 'type'
		@visibility = sync.observer 'visibility'
		@isStatic   = sync.observer 'isStatic'

		super

class AttributeViewModel extends MemberViewModel

class OperationViewModel extends MemberViewModel
	constructor : (@sync) ->
		@params = sync.observer 'params',
			classAdapter : ParamViewModel

		super

class ParamViewModel extends BaseViewModel
	constructor : (@sync) ->
		@name = sync.observer 'name'
		@type = sync.observer 'type'

		super

class RelationshipViewModel extends BaseViewModel

module.exports = ClassDiagramViewModel