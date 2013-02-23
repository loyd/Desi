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
		
		@chosenEssential = ko.observable null
		@openPopover     = ko.observable null
		@essentialMenuElement = ko.observable null

		@creatingMenuPosX = ko.observable()
		@creatingMenuPosY = ko.observable()

		@isChosen = no
		@isMoved  = no
		@linking  = no

		document.addEventListener 'mouseup', =>
			(=> @linking = no).defer()

		onresize '#main', =>
			do @refreshSizes if @isChosen

		subscr = @essentialMenuElement.subscribe (elem) =>
			do subscr.dispose
			onresize elem, =>
				# I love this hack :D
				@essentialMenuElement @essentialMenuElement()

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

	#### Adding essentials and relationships

	addEssential : (x, y) ->
		sync = new Synchronizer @spec.data.essentials.item
		ess  = new EssentialViewModel sync
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

	removeEssential : (ess) ->
		@essentials.remove ess
		if @chosenEssential() is ess
			@chooseEssential null

	addRelationship : (from, to) ->
		sync = new Synchronizer @spec.data.relationships.item
		rel  = new RelationshipViewModel sync
		rel.fromEssential from.ref()
		rel.toEssential to.ref()
		from.addRelationship rel
		to.addRelationship rel
		@relationships.push rel

	removeRelationship : (rel) ->
		@relationships.remove rel
		rel.fromEssential.deref().removeRelationship rel
		rel.toEssential.deref().removeRelationship rel

	@delegate('click') (el, event) ->
		return if event.target isnt @element()
		if @isMoved
			@isMoved = no
			return

		@openMenu null
		@chooseEssential null
		{left, top} = @element().getBoundingClientRect()
		left = event.clientX - left
		top  = event.clientY - top
		@creatingMenuPosX left
		@creatingMenuPosY top
		@openMenu 'creating'

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
		@openMenu null
		@removeEssential @chosenEssential()

	@delegate('click', '.btn-edit-essential') ->
		@openMenu 'essential'

	@delegate('mousedown', '.btn-link-essential') ->
		@linking = yes

	@delegate('mouseup', '.essential') (ess) ->
		return unless @linking
		return if ess is @chosenEssential()

		@addRelationship @chosenEssential(), ess

	@delegate('mousedown', '.control-menu') (el, event) ->
		return unless ~" #{event.target.className} ".indexOf ' control-menu '
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

	@delegate('click', '.essential-menu .color') (color) ->
		@chosenEssential().color color

	@delegate('click', '.essential-menu .btn-add-attribute') ->
		do @chosenEssential().addAttribute

	@delegate('click', '.essential-menu .btn-rm-attribute') (attr) ->
		@chosenEssential().removeAttribute attr

	@delegate('click', '.essential-menu .btn-add-operation') ->
		do @chosenEssential().addOperation

	@delegate('click', '.essential-menu .btn-rm-operation') (oper) ->
		@chosenEssential().removeOperation oper

	@delegate('click', '.essential-menu .btn-params-toggle') (oper) ->
		oper.paramsAreOpen !oper.paramsAreOpen()

	@delegate('click', '.essential-menu .btn-add-param') (oper) ->
		do oper.addParam

	@delegate('click', '.essential-menu .btn-static-toggle') (member) ->
		member.isStatic !member.isStatic()

	@delegate('click', '.essential-menu .btn-rm-param') (param, event) ->
		oper = ko.contextFor(event.target).$parent
		oper.removeParam param

	#### Creating menu

	@delegate('click', '.creating-menu .btn-make-class') (el, event) ->
		realX = @creatingMenuPosX()
		realY = @creatingMenuPosY()

		scaleFactor = @scaleFactor()
		relX = @originX() + realX / scaleFactor
		relY = @originY() + realY / scaleFactor
		@addEssential relX, relY
		@chooseEssential @essentials().last()
		@openMenu 'control'

class EssentialViewModel extends BaseViewModel
	MIN_HEADER_PADDING = 8

	constructor : (@sync) ->
		@name  = sync.observer 'name'
		@posX  = sync.observer 'posX'
		@posY  = sync.observer 'posY'
		@color = sync.observer 'color'

		@attributes = sync.observer 'attributes',
			classAdapter : AttributeViewModel
		@attributes.subscribe => do @placeAttributes
		do @placeAttributes

		@operations = sync.observer 'operations',
			classAdapter : OperationViewModel
		@operations.subscribe => do @placeOperations
		do @placeOperations

		@relationships = sync.observer 'relationships'

		@isMoved   = ko.observable no
		@isChosen  = ko.observable no

		super

	textSize = (sel, text) ->
		countTextSize ".essential .header #{sel}", text

	@computed \
	width : ->
		w = Math.max(
			MIN_HEADER_PADDING * 2 + textSize('.name', @name()).width
			(@attributes().map (attr) -> attr.minWidth()).max()
			(@operations().map (oper) -> oper.minWidth()).max()
		)

		attr.width w for attr in @attributes()
		oper.width w for oper in @operations()

		w

	@computed \
	height : ->
		@headerHeight() + @attributesHeight() + @operationsHeight()

	addAttribute : ->
		sync = new Synchronizer @spec.data.attributes.item
		attr = new AttributeViewModel sync
		@attributes.push attr

	removeAttribute : (attr) ->
		@attributes.remove attr

	addOperation : ->
		sync = new Synchronizer @spec.data.operations.item
		oper = new OperationViewModel sync
		@operations.push oper

	removeOperation : (oper) ->
		@operations.remove oper

	addRelationship : (rel) ->
		sync = new Synchronizer @spec.data.relationships.item
		@relationships.push sync.observer()

	removeRelationship : (rel) ->
		@relationships.remove (ptr) ->
			ptr.deref() is rel

	#### Header section
	
	headerHeight : ->
		MIN_HEADER_PADDING * 2 + textSize('.name', @name()).height

	@computed \
	namePosX : ->
		@width() / 2

	@computed \
	namePosY : ->
		@headerHeight() / 2

	#### Attributes section

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

	#### Operations section
	
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
		
MIN_GOR_PADDING = 5
VERT_PADDING = 3
INTERVAL = 2
textSize = (text) -> countTextSize ".member", text

class MemberViewModel extends BaseViewModel
	constructor : (@sync) ->
		@name       = sync.observer 'name'
		@type       = sync.observer 'type'
		@visibility = sync.observer 'visibility'
		@isStatic   = sync.observer 'isStatic'

		@posY  = ko.observable()
		@width = ko.observable()

		super

	@computed \
	height : ->
		textSize(@name()[0].up()).height + VERT_PADDING * 2

	visibilityPosX : MIN_GOR_PADDING

	@computed \
	namePosX : ->
		@visibilityPosX + textSize(@visibility()).width + INTERVAL

	@computed \
	textPosY : ->
		@height() / 2

	separatorLinePosX1 : MIN_GOR_PADDING / 2

	@computed \
	separatorLinePosX2 : ->
		@width() - MIN_GOR_PADDING / 2

class AttributeViewModel extends MemberViewModel
	@computed \
	minWidth : ->
		@typePosX() + textSize(@type()).width + MIN_GOR_PADDING

	@computed \
	separatorPosX : ->
		@namePosX() + textSize(@name()).width + INTERVAL

	@computed \
	typePosX : ->
		@separatorPosX() + textSize(':').width + INTERVAL

class OperationViewModel extends MemberViewModel
	constructor : (@sync) ->
		super

		@params = sync.observer 'params',
			classAdapter : ParamViewModel
		do @placeParams

		@paramsAreOpen = ko.observable no

	addParam : ->
		sync  = new Synchronizer @spec.data.params.item
		param = new ParamViewModel sync
		@params.push param

	removeParam : (param) ->
		@params.remove param

	@computed \
	widthParams : ->
		last = @params().last()
		if last
			last.posX() + last.width()
		else 0

	@computed \
	placeParams : ->
		posX = -(textSize(',').width)
		for param in @params()
			param.posX posX
			posX += param.width()
		return

	@computed \
	minWidth : ->
		@typePosX() + textSize(@type()).width + MIN_GOR_PADDING

	@computed \
	openScobePosX : ->
		@namePosX() + textSize(@name()).width + INTERVAL/2

	@computed \
	paramsPosX : ->
		@openScobePosX() + textSize('(').width +
			INTERVAL - textSize(',').width - INTERVAL

	@computed \
	closeScobePosX : ->
		@paramsPosX() + @widthParams() + INTERVAL

	@computed \
	separatorPosX : ->
		@closeScobePosX() + textSize(')').width + INTERVAL

	@computed \
	typePosX : ->
		@separatorPosX() + textSize(':').width + INTERVAL

class ParamViewModel extends BaseViewModel
	constructor : (@sync) ->
		@name = sync.observer 'name'
		@type = sync.observer 'type'

		@posX = ko.observable()

		super

	@computed \
	width : ->
		@typePosX() + textSize(@type()).width

	@computed \
	commaPosX : ->
		INTERVAL / 2

	@computed \
	namePosX : ->
		textSize(',').width + INTERVAL

	@computed \
	separatorPosX : ->
		@namePosX() + textSize(@name()).width + INTERVAL

	@computed \
	typePosX : ->
		@separatorPosX() + textSize(':').width + INTERVAL

class RelationshipViewModel extends BaseViewModel
	constructor : (@sync) ->
		@type = sync.observer 'type'
		@fromEssential = sync.observer 'fromEssential'
		@toEssential = sync.observer 'toEssential'

		super

	@computed \
	fromPosX : ->
		@fromEssential.deref().posX()

	@computed \
	toPosX : ->
		@toEssential.deref().posX()

	@computed \
	fromPosY : ->
		@fromEssential.deref().posY()

	@computed \
	toPosY : ->
		@toEssential.deref().posY()

module.exports = ClassDiagramViewModel