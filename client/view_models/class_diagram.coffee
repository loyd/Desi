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
		
		@chosenEssential     = ko.observable null
		@openPopover         = ko.observable null
		@colorPopoverElement = ko.observable null

		@isChosen = no
		@isMoved  = no

		onresize '#main', =>
			do @refreshSizes if @isChosen

		super

	refreshSizes : ->
		style = getComputedStyle(@element(), null)

		@width  parseInt style.width, 10
		@height parseInt style.height, 10

	startEditing : ->
		@isChosen = yes
		(=> do @refreshSizes).defer()

	stopEditing : ->
		@isChosen = no

	#### Adding essentials

	addEssential : (x, y) ->
		sync = new Synchronizer @spec.data.essentials.item
		ess = new EssentialViewModel sync
		ess.posX x - ess.width() / 2
		ess.posY y - ess.headerHeight() / 2
		@essentials.push ess

	chooseEssential : (ess) ->
		@chosenEssential()?.isChosen no
		@chosenEssential ess
		if ess?
			ess.isChosen yes

	@delegate('click') (el, event) ->
		return unless event.target is @element()
		if @isMoved
			@isMoved = no
			return

		if @chosenEssential()
			@chooseEssential null
			return

		{left, top} = @element().getBoundingClientRect()
		scaleFactor = @scaleFactor()
		x = @originX() + (event.clientX - left) / scaleFactor
		y = @originY() + (event.clientY - top)  / scaleFactor
		@addEssential x, y

	#### Moving essential

	@delegate('mousedown', '.essential') \
	essentialMouseDown : (ess, event) ->
		wasChosen = ess.isChosen()
		unless wasChosen
			@chooseEssential null

		{posX, posY} = ess
		prevX = event.clientX
		prevY = event.clientY

		mouseMove = (e) =>
			unless ess.isMoved()
				ess.isMoved yes
				@chooseEssential null
			scaleFactor = @scaleFactor()
			posX posX() + (e.clientX - prevX) / scaleFactor
			posY posY() + (e.clientY - prevY) / scaleFactor
			prevX = e.clientX
			prevY = e.clientY

		mouseUp = (e) =>
			document.removeEventListener 'mousemove', mouseMove, on
			document.removeEventListener 'mouseup', mouseUp, on

			if e.target isnt event.target
				ess.isMoved no

			if wasChosen
				@chooseEssential ess

		document.addEventListener 'mousemove', mouseMove, on
		document.addEventListener 'mouseup', mouseUp, on

		do event.preventDefault

	#### Scaling and shifting

	shift : (x, y) ->
		scaleFactor = @scaleFactor()
		@originX @originX() - x / scaleFactor
		@originY @originY() - y / scaleFactor

	scale : (sign) ->
		newFactor = @scaleFactor() + SCALE_DIFF * sign
		@scaleFactor newFactor if newFactor > 0

	@computed \
	viewBox : ->
		scaleFactor = @scaleFactor()
		uuWidth  = @width()  / scaleFactor
		uuHeight = @height() / scaleFactor
		"#{@originX()} #{@originY()} #{uuWidth} #{uuHeight}"

	@computed \
	bgSize : ->
		value = 5 * @scaleFactor()
		"#{value}mm #{value}mm"

	@computed \
	bgPosition : ->
		scaleFactor = @scaleFactor()
		"#{-@originX() * scaleFactor} #{-@originY() * scaleFactor}"

	nameWheelEvent = ['wheel', 'mousewheel'].scan((name) ->
		('on' + name) of document) || 'MozMousePixelScroll'

	@delegate(nameWheelEvent) (el, event) ->
		sign = (event.deltaY || event.detail || event.wheelDelta).sign()
		
		oldScaleFactor = @scaleFactor()
		@scale sign
		relFactor = 1 - @scaleFactor() / oldScaleFactor

		@shift event.clientX * relFactor, event.clientY * relFactor

		do event.preventDefault

	@delegate('mousedown') (el, event) ->
		return if event.target isnt @element()
		{originX, originY} = this
		prevX = event.clientX
		prevY = event.clientY

		mouseMove = (e) =>
			@shift(e.clientX - prevX, e.clientY - prevY)
			prevX    = e.clientX
			prevY    = e.clientY
			@isMoved = yes

		mouseUp = (e) =>
			document.removeEventListener 'mousemove', mouseMove, on
			document.removeEventListener 'mouseup', mouseUp, on

			if e.target isnt event.target
				@isMoved = no

		document.addEventListener 'mousemove', mouseMove, on
		document.addEventListener 'mouseup', mouseUp, on

		do event.preventDefault

	#### Control panel

	ifChosenEssential = (fn) -> ->
		fn.apply this, arguments if @chosenEssential()

	@computed \
	controlPanelPosX : ifChosenEssential ->
		(@chosenEssential().posX() - @originX()) * @scaleFactor()

	@computed \
	controlPanelPosY : ifChosenEssential ->
		(@chosenEssential().posY() - @originY()) * @scaleFactor()

	@computed \
	controlPanelWidth : ifChosenEssential ->
		@chosenEssential().width() * @scaleFactor()

	@computed \
	controlPanelHeight : ifChosenEssential ->
		@chosenEssential().height() * @scaleFactor()

	@delegate('click', '.btn-rm-essential') ->
		@essentials.remove @chosenEssential()
		@chooseEssential null

	@delegate('click', '.btn-color-essential') ->
		@openPopover 'color'

	@delegate('mousedown', '.control-panel') (el, event) ->
		@essentialMouseDown @chosenEssential(), event

	@delegate('click', '.essential') (ess, event) ->
		if ess.isMoved()
			ess.isMoved no
			return

		@chooseEssential ess

		do event.preventDefault

	#### Color popover
	
	colorPopoverWidth : ->
		@colorPopoverElement()?.getBoundingClientRect().width || 0

	colorPopoverHeight : ->
		style = getComputedStyle(@colorPopoverElement(), null)
		if style
			parseInt style.height + style.marginTop, 10
		else 0

	@computed \
	colorPopoverPosition : ifChosenEssential ->
		ess = @chosenEssential()
		bottomPosY = (ess.posY() - @originY() + ess.height()) * @scaleFactor()
		essBottom = @height() - bottomPosY

		if essBottom > @colorPopoverHeight()
			'bottom'
		else
			'top'

	@computed \
	colorPopoverPosX : ifChosenEssential ->
		popoverWidth = @colorPopoverWidth()
		ess = @chosenEssential()
		essRealPosX = (ess.posX() - @originX()) * @scaleFactor()
		posX = essRealPosX + (ess.width() * @scaleFactor() - popoverWidth) / 2
		maxPosX = @width() - popoverWidth
		
		if 0 <= posX <= maxPosX
			posX
		else if maxPosX < posX
			maxPosX
		else 0

	@computed \
	colorPopoverPosY : ifChosenEssential ->
		ess = @chosenEssential()
		realPosY = (ess.posY() - @originY()) * @scaleFactor()
		if @colorPopoverPosition() == 'top'
			realPosY - @colorPopoverHeight()
		else
			realPosY + ess.height() * @scaleFactor()

	@computed \
	colorPopoverArrowPos : ifChosenEssential ->
		ess  = @chosenEssential()
		diff = ess.width() / 2 + (ess.posY() - @colorPopoverPosX())
		diff / @colorPopoverWidth() * 100 | 0

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

		@isMoved  = ko.observable no
		@isChosen = ko.observable no
		@color    = ko.observable '#FFF'

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