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

		@openMenu = ko.observable null
		
		@chosenEssential  = ko.observable null
		@openPopover      = ko.observable null
		@essentialMenuElement = ko.observable null

		@isChosen = no
		@isMoved  = no

		onresize '#main', =>
			do @refreshSizes if @isChosen

		super

	calcExternSize : (size) ->
		size * @scaleFactor()

	calcExternPosX : (pos) ->
		(pos - @originX()) * @scaleFactor()

	calcExternPosY : (pos) ->
		(pos - @originY()) * @scaleFactor()

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
			index = @essentials.indexOf ess
			@essentials.move index, @essentials().length-1

	@delegate('click') (el, event) ->
		return unless event.target is @element()
		if @isMoved
			@isMoved = no
			return

		if @openMenu()
			@openMenu null
			@chooseEssential null
			return

		{left, top} = @element().getBoundingClientRect()
		scaleFactor = @scaleFactor()
		x = @originX() + (event.clientX - left) / scaleFactor
		y = @originY() + (event.clientY - top)  / scaleFactor
		@addEssential x, y

	#### Clicking and moving essential

	@delegate('mousedown', '.essential') \
	essentialMouseDown : (ess, event) ->
		if ess isnt @chosenEssential()
			@chooseEssential ess
			@openMenu 'control'

		menuName = @openMenu() ? 'control'

		{posX, posY} = ess
		prevX = event.clientX
		prevY = event.clientY

		mouseMove = (e) =>
			unless ess.isMoved()
				isClick = no
				ess.isMoved yes
				@openMenu null
				@chooseEssential null

			scaleFactor = @scaleFactor()
			posX posX() + (e.clientX - prevX) / scaleFactor
			posY posY() + (e.clientY - prevY) / scaleFactor
			{clientX : prevX, clientY : prevY} = e

		mouseUp = (e) =>
			document.removeEventListener 'mousemove', mouseMove, on
			document.removeEventListener 'mouseup', mouseUp, on

			ess.isMoved no
			@chooseEssential ess
			@openMenu menuName

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

	#### Control menu

	@computed \
	controlMenuPosX : ->
		if @openMenu() == 'control'
			@calcExternPosX @chosenEssential().posX()

	@computed \
	controlMenuPosY : ->
		if @openMenu() == 'control'
			@calcExternPosY @chosenEssential().posY()

	@computed \
	controlMenuWidth : ->
		if @openMenu() == 'control'
			@calcExternSize @chosenEssential().width()

	@computed \
	controlMenuHeight : ->
		if @openMenu() == 'control'
			@calcExternSize @chosenEssential().height()

	@delegate('click', '.btn-rm-essential') ->
		@essentials.remove @chosenEssential()
		@openMenu null
		@chooseEssential null

	@delegate('click', '.btn-edit-essential') ->
		@openMenu 'essential'

	@delegate('mousedown', '.control-menu') (el, event) ->
		@essentialMouseDown @chosenEssential(), event

	#### Essential menu
	
	essentialMenuWidth : ->
		return unless @essentialMenuElement()
		s = getComputedStyle(@essentialMenuElement(), null)
		[s.marginLeft, s.width, s.marginRight].reduce (res, size) ->
			res + (parseInt(size, 10) || 0).abs()
		, 0

	essentialMenuHeight : ->
		return unless @essentialMenuElement()
		@essentialMenuElement().getBoundingClientRect().height

	@computed \
	essentialMenuPosition : ->
		return if @openMenu() != 'essential'
		ess = @chosenEssential()
		spaceBefore = @calcExternPosX ess.posX()
		spaceAfter  = @width() - spaceBefore - @calcExternSize ess.width()

		if spaceBefore > spaceAfter then 'left' else 'right'

	@computed \
	essentialMenuPosX : ->
		return if @openMenu() != 'essential'
		ess     = @chosenEssential()
		essPosX = @calcExternPosX ess.posX()

		if @essentialMenuPosition() == 'left'
			essPosX - @essentialMenuWidth()
		else
			essPosX + @calcExternSize ess.width()

	@computed \
	essentialMenuPosY : ->
		return if @openMenu() != 'essential'
		ess = @chosenEssential()
		popoverHeight = @essentialMenuHeight()
		centerPosY = @calcExternPosY(ess.posY()) +
			@calcExternSize(ess.height()) / 2

		posY = centerPosY - popoverHeight / 2
		if posY < 0
			posY = 0
		else if posY + popoverHeight > @height()
			posY = @height() - popoverHeight

		posY

	@computed \
	essentialMenuArrowPos : ->
		return if @openMenu() != 'essential'
		ess = @chosenEssential()
		menuPosY  = @essentialMenuPosY()
		arrowPosY = @calcExternPosY(ess.posY()) +
			@calcExternSize(ess.height()) / 2

		(arrowPosY - menuPosY) / @essentialMenuHeight() * 100

	@delegate('click', '.essential-menu .name') ->
		@chosenEssential().isRenamed yes

	@delegate('click', '.essential-menu .color') (color) ->
		@chosenEssential().color color

class EssentialViewModel extends BaseViewModel
	viewRoot : '.essential'

	MIN_HEADER_PADDING = 10

	constructor : (@sync) ->
		@name  = sync.observer 'name'
		@posX  = sync.observer 'posX'
		@posY  = sync.observer 'posY'
		@color = sync.observer 'color'

		@attributes = sync.observer 'attributes',
			classAdapter : AttributeViewModel
		@attributes.subscribe => @placeAttributes

		@operations = sync.observer 'operations',
			classAdapter : OperationViewModel
		@operations.subscribe => @placeOperations

		@isMoved   = ko.observable no
		@isChosen  = ko.observable no
		@isRenamed = ko.observable no

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