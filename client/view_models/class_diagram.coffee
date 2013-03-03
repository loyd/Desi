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
		
		@chosenEssential    = ko.observable null
		@chosenRelationship = ko.observable null
		@openPopover        = ko.observable null
		@essentialMenuElement    = ko.observable null
		@relationshipMenuElement = ko.observable null
		@fakeRelationship = ko.observable null
		@fakeEssential = ko.observable null
		@fakeRelationshipIsVisible = ko.observable no
		@fakeEssentialIsVisible = ko.observable no

		@creatingMenuPosX = ko.observable()
		@creatingMenuPosY = ko.observable()

		@isChosen = no
		@isMoved  = no
		@linking  = ko.observable no
		@linking.subscribe (value) =>
			if value
				@fakeRelationshipIsVisible yes
			else
				@fakeRelationshipIsVisible no
				@fakeEssentialIsVisible no

		document.addEventListener 'mouseup', =>
			(=> @linking no).defer()

		onresize '#main', =>
			do @refreshSizes if @isChosen

		essSubscr = @essentialMenuElement.subscribe (elem) =>
			do essSubscr.dispose
			onresize elem, =>
				# I love this hack :D
				@essentialMenuElement @essentialMenuElement()

		relSubscr = @relationshipMenuElement.subscribe (elem) =>
			do relSubscr.dispose
			onresize elem, =>
				@relationshipMenuElement @relationshipMenuElement()

		super

		do @makeFakeElements

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

	@delegate('click') (el, event) ->
		return if event.target isnt @element()
		if @isMoved
			@isMoved = no
			return

		@openMenu null
		@chooseRelationship null
		@chooseEssential null
		{left, top} = @element().getBoundingClientRect()
		left = event.clientX - left
		top  = event.clientY - top
		@creatingMenuPosX left
		@creatingMenuPosY top
		@openMenu 'creating'

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

	chooseRelationship : (rel) ->
		@chosenRelationship()?.isChosen no
		@chosenRelationship rel
		if rel?
			rel.isChosen yes
			index = @relationships.indexOf rel
			@relationships.move index, @relationships().length-1

	removeEssential : (ess) ->
		for relPtr in ess.relationships()
			@removeRelationship relPtr.deref()

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

	makeFakeElements : ->
		relSync = new Synchronizer @spec.data.relationships.item, null, yes
		rel = new RelationshipViewModel relSync
		
		essSync = new Synchronizer @spec.data.essentials.item, null, yes
		ess = new EssentialViewModel essSync

		Synchronizer.registerPid ess.sync.pid, ess

		@fakeEssential ess
		@fakeRelationship rel

	removeRelationship : (rel) ->
		rel.fromEssential.deref().removeRelationship rel
		rel.toEssential.deref().removeRelationship rel
		@relationships.remove rel

	#### Clicking and moving essential

	@delegate('mousedown', '.essential') \
	essentialMouseDown : (ess, event) ->
		if ess isnt @chosenEssential()
			@openMenu null
			@chooseRelationship null
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

	@delegate('click', '.relationship-zone') (rel) ->
		@openMenu null
		@chooseEssential null
		@chooseRelationship rel
		@openMenu 'relationship'

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
		value = 1.5 * @scaleFactor()
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
			unless @isMoved
				@isMoved = yes
				if @openMenu() == 'creating'
					@openMenu null

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
		fakeRel = @fakeRelationship()
		fakeEss = @fakeEssential()
		fakeRel.fromEssential @chosenEssential().ref()
		fakeRel.toEssential @fakeEssential().ref()
		@linking yes
		@fakeEssentialIsVisible yes

		{left, top} = @element().getBoundingClientRect()
		scaleFactor = @scaleFactor()
		someX = @originX() - fakeEss.width() / 2
		someY = @originY() - fakeEss.height() / 2

		menuIsClosed = no
		mouseMove = (event) =>
			unless menuIsClosed
				@openMenu null
				menuIsClosed = yes

			fakeEss.posX someX + (event.clientX - left) / scaleFactor
			fakeEss.posY someY + (event.clientY - top) / scaleFactor

		mouseUp = =>
			document.removeEventListener 'mousemove', mouseMove, off
			document.removeEventListener 'mouseup', mouseUp, off

		document.addEventListener 'mousemove', mouseMove, off
		document.addEventListener 'mouseup', mouseUp, off

	@delegate('mouseover', '.essential') (ess) ->
		if @linking()
			if @fakeEssential() isnt ess
				@fakeEssentialIsVisible no
			@fakeRelationship().toEssential ess.ref()

	@delegate('mouseout', '.essential') ->
		if @linking()
			@fakeRelationship().toEssential @fakeEssential().ref()
			@fakeEssentialIsVisible yes

	@delegate('mouseup', '.essential') (ess) ->
		return unless @linking()
		@linking no
		if ess is (fake = @fakeEssential())
			@addEssential fake.posX() + fake.width() / 2,
				fake.posY() + fake.height() / 2

			ess = @essentials().last()

		@addRelationship @chosenEssential(), ess
		@chooseRelationship @relationships().last()
		@openMenu 'relationship'
		@chooseEssential null

	@delegate('mousedown', '.control-menu') (el, event) ->
		return unless ~" #{event.target.className} ".indexOf ' control-menu '
		@essentialMouseDown @chosenEssential(), event

	#### Utils for menu

	calcMenuWidth = (elem) ->
		return unless elem
		s = getComputedStyle(elem, null)
		[s.marginLeft, s.width, s.marginRight].reduce (res, size) ->
			res + (parseInt(size, 10) || 0).abs()
		, 0

	calcMenuHeight = (elem) ->
		return unless elem
		s = getComputedStyle(elem, null)
		[s.marginTop, s.height, s.marginBottom].reduce (res, size) ->
			res + (parseInt(size, 10) || 0).abs()
		, 0

	#### Essential menu

	essentialMenuWidth : ->
		calcMenuWidth @essentialMenuElement()

	essentialMenuHeight : ->
		calcMenuHeight @essentialMenuElement()

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
			posY = Math.min 0, @calcExternPosY ess.posY() + ess.height()
		else if posY + popoverHeight > @height()
			posY = Math.max(@height(), @calcExternPosY ess.posY()) - popoverHeight

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

	@delegate('click', '.essential-menu .btn-abstract-toggle') (ess) ->
		ess.isAbstract !ess.isAbstract()

	@delegate('click', '.essential-menu .btn-rm-param') (param, event) ->
		oper = ko.contextFor(event.target).$parent
		oper.removeParam param

	#### Relationship menu

	relationshipMenuWidth : ->
		calcMenuWidth @relationshipMenuElement()

	relationshipMenuHeight : ->
		calcMenuHeight @relationshipMenuElement()

	@computed \
	relationshipMenuPart : ->
		return if @openMenu() != 'relationship'
		rel = @chosenRelationship()
		(rel.fromCrossPart() + rel.toCrossPart()) / 2

	@computed \
	relationshipMenuPosition : ->
		return if @openMenu() != 'relationship'
		rel   = @chosenRelationship()
		part  = @relationshipMenuPart()
		angle = rel.calcTangentAngle(part).abs()
		if 45 < angle < 135
			posX = @calcExternPosX rel.calcX part
			if Math.max(posX, @width() - posX) == posX
				'left'
			else
				'right'
		else
			posY = @calcExternPosY rel.calcY part
			if Math.max(posY, @height() - posY) == posY
				'top'
			else
				'bottom'

	@computed \
	relationshipMenuPosX : ->
		return if @openMenu() != 'relationship'
		rel  = @chosenRelationship()
		patX = @calcExternPosX rel.calcX @relationshipMenuPart()
		pos  = @relationshipMenuPosition()
		if pos == 'left'
			patX - @relationshipMenuWidth()
		else if pos == 'right'
			patX
		else
			patX - @relationshipMenuWidth() / 2

	@computed \
	relationshipMenuPosY : ->
		return if @openMenu() != 'relationship'
		rel  = @chosenRelationship()
		patY = @calcExternPosY rel.calcY @relationshipMenuPart()
		pos  = @relationshipMenuPosition()
		if pos == 'top'
			patY - @relationshipMenuHeight()
		else if pos == 'bottom'
			patY
		else
			patY - @relationshipMenuHeight() / 2

	@delegate('click', '.relationship-menu .types .btn') (type) ->
		rel = @chosenRelationship()
		return if rel.isItself() && type in ['generalization', 'realization']
		@chosenRelationship().type type

	@delegate('click', '.relationship-menu .rm-relationship') (rel) ->
		@removeRelationship rel
		@openMenu null

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
		@isAbstract = sync.observer 'isAbstract'

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
		ptr = sync.observer()
		ptr rel.ref()
		@relationships.push ptr

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
			sum + attr.height
		, 0

	placeAttributes : ->
		posY = 0
		for member in @attributes()
			member.posY posY
			posY += member.height
		return

	@computed \
	attributesPosY : @::headerHeight

	@computed \
	attributesVisible : ->
		@attributes().length

	#### Operations section
	
	operationsHeight : ->
		@operations().reduce (sum, oper) ->
			sum + oper.height
		, 0

	placeOperations : ->
		posY = 0
		for member in @operations()
			member.posY posY
			posY += member.height
		return

	@computed \
	operationsPosY : ->
		@attributesPosY() + @attributesHeight()

	@computed \
	operationsVisible : ->
		@operations().length
		
MIN_GOR_PADDING = 5
VERT_PADDING = 3
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

	height : textSize('A').height + VERT_PADDING * 2

	textPosX : MIN_GOR_PADDING
	@computed \
	textPosY : ->
		@height / 2

	separatorLinePosX1 : MIN_GOR_PADDING / 2
	@computed \
	separatorLinePosX2 : ->
		@width() - MIN_GOR_PADDING / 2

	@computed \
	minWidth : ->
		textSize(@text()).width + MIN_GOR_PADDING * 2

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
		@params.remove param

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

class RelationshipViewModel extends BaseViewModel
	freeID = 0

	constructor : (@sync) ->
		@type             = sync.observer 'type'
		@fromEssential    = sync.observer 'fromEssential'
		@toEssential      = sync.observer 'toEssential'
		@fromMultiplicity = sync.observer 'fromMultiplicity'
		@toMultiplicity   = sync.observer 'toMultiplicity'
		@fromIndicator    = sync.observer 'fromIndicator'
		@toIndicator      = sync.observer 'toIndicator'

		@isChosen = ko.observable no
		@pathID = "__path__id__#{freeID++}"
		@pathElement = ko.observable null

		super

		@isClassLevel.subscribe (value) =>
			if value
				@fromMultiplicity ''
				@toMultiplicity ''
				@fromIndicator ''
				@toIndicator ''

	@computed \
	isClassLevel : ->
		@type() in ['generalization', 'realization']

	@computed \
	isItself : ->
		@fromEssential() == @toEssential()

	@computed \
	fromX : ->
		from  = @fromEssential.deref()
		fromX = from.posX() + from.width() / 2

	@computed \
	fromY : ->
		from = @fromEssential.deref()
		if @isItself()
			from.posY() + from.height() * 4/5
		else
			from.posY() + from.height() / 2

	SHIFT_PART = 10
	@computed \
	midX : ->
		if @isItself()
			@fromX() + @fromEssential.deref().width() * 2
		else
			fromPosX = @fromX()
			toPosX   = @toX()

			fromPosX + (toPosX - fromPosX) / SHIFT_PART

	@computed \
	midY : ->
		fromPosY = @fromY()
		toPosY   = @toY()

		toPosY - (toPosY - fromPosY) / SHIFT_PART

	@computed \
	toX : ->
		to = @toEssential.deref()
		to.posX() + to.width() / 2

	@computed \
	toY : ->
		to = @toEssential.deref()
		if @isItself()
			to.posY() + to.height() / 5
		else
			to.posY() + to.height() / 2

	@computed \
	path : ->
		"""M #{@fromX()} #{@fromY()} Q
			#{@midX()}, #{@midY()}
		#{@toX()} #{@toY()}"""

	@computed \
	reversedPath : ->
		"""M #{@toX()} #{@toY()} Q
			#{@midX()}, #{@midY()}
		#{@fromX()} #{@fromY()}"""

	calcPart = (A, B, C, D) ->
		d = -A + 2*B - C
		if d == 0
			if A != B
				(A - D) / (2 * (A - B))
			else null
		else
			r = (-A*C + A*D + B*B - 2*B*D + C*D).sqrt()
			t = (r - A + B) / d
			unless 0 <= t <= 1
				t = (-r - A + B) / d

			if 0 <= t <= 1 then t else null

	calcPartAtX : (x) ->
		calcPart(@fromX(), @midX(), @toX(), x)

	calcPartAtY : (y) ->
		calcPart(@fromY(), @midY(), @toY(), y)

	INACCURACY = 2
	calcPartFor : (ess) ->
		eWidth  = ess.width()
		eHeight = ess.height()
		ePosX   = ess.posX()
		ePosY   = ess.posY()

		part = @calcPartAtX(ePosX) ? @calcPartAtX(ePosX + eWidth)
		if part?
			y = @calcY part
			if ePosY - INACCURACY < y < ePosY + eHeight + INACCURACY
				return part

		part = @calcPartAtY(ePosY) ? @calcPartAtY(ePosY + eHeight)
		if part?
			x = @calcX part
			if ePosX - INACCURACY < x < ePosX + eWidth + INACCURACY
				return part

	@computed \
	fromCrossPart : ->
		@calcPartFor(@fromEssential.deref()) ? 0

	@computed \
	toCrossPart : ->
		@calcPartFor(@toEssential.deref()) ? 1

	calcX : (p) ->
		r = 1 - p
		r * r * @fromX() + 2 * p * r * @midX() + p * p * @toX()

	calcY : (p) ->
		r = 1 - p
		r * r * @fromY() + 2 * p * r * @midY() + p * p * @toY()

	DELTA_PART = .05
	calcTangentAngle : (part) ->
		helpPart = if part > 0.5 then part - DELTA_PART else part + DELTA_PART
		deltaX = @calcX(part) - @calcX(helpPart)

		Math.atan2(
			@calcY(part) - @calcY(helpPart), deltaX
		).toDegree()

	@computed \
	fromCrossAngle : ->
		part = @fromCrossPart()
		help = part + DELTA_PART
		Math.atan2(
			@calcY(part) - @calcY(help),
			@calcX(part) - @calcX(help)
		).toDegree()

	@computed \
	toCrossAngle : ->
		part = @toCrossPart()
		help = part - DELTA_PART
		Math.atan2(
			@calcY(part) - @calcY(help),
			@calcX(part) - @calcX(help)
		).toDegree()

	@computed \
	fromCrossX : ->
		@calcX @fromCrossPart()

	@computed \
	fromCrossY : ->
		@calcY @fromCrossPart()

	@computed \
	fromIsThick : ->
		@type() in ['aggregation', 'composition']

	@computed \
	toIsThick : ->
		!@fromIsThick()

	@computed \
	toCrossX : ->
		@calcX @toCrossPart()

	@computed \
	toCrossY : ->
		@calcY @toCrossPart()

	@computed \
	tipTransform : ->
		if @fromIsThick() && !@isItself()
			"translate(#{@fromCrossX()}, #{@fromCrossY()})" +
			"rotate(#{@fromCrossAngle()})"
		else
			"translate(#{@toCrossX()}, #{@toCrossY()})" +
			"rotate(#{@toCrossAngle()})"

	MULTIPLICITY_DIST = 12
	MULTIPLICITY_FACTOR = 1.2
	calcMultiplicityAngle : (startAngle, indicator) ->
		s = if indicator.length == 0
			if 90 < startAngle < 180 || -90 < startAngle < 0 then -1 else 1
		else if @pathMode() == 'def' then 1 else -1
	
		(startAngle + s * 45).toRadian()

	@computed \
	fromMultiplicityDist : ->
		dist = MULTIPLICITY_DIST
		if @fromIsThick()
			dist *= MULTIPLICITY_FACTOR
		if @fromMultiplicity().length > 1
			dist *= MULTIPLICITY_FACTOR
		if @fromIndicator().length > 0
			dist *= MULTIPLICITY_FACTOR
			
		dist

	@computed \
	toMultiplicityDist : ->
		dist = MULTIPLICITY_DIST
		if @toIsThick()
			dist *= MULTIPLICITY_FACTOR
		if @toMultiplicity().length > 1
			dist *= MULTIPLICITY_FACTOR
		if @toIndicator().length > 0
			dist *= MULTIPLICITY_FACTOR

		dist

	@computed \
	fromMultiplicityX : ->
		angle = @calcMultiplicityAngle @fromCrossAngle(), @fromIndicator()
		@fromCrossX() - @fromMultiplicityDist() * angle.cos()

	@computed \
	fromMultiplicityY : ->
		angle = @calcMultiplicityAngle @fromCrossAngle(), @fromIndicator()
		@fromCrossY() - @fromMultiplicityDist() * angle.sin()

	@computed \
	toMultiplicityX : ->
		angle = @calcMultiplicityAngle @toCrossAngle(), @toIndicator()
		@toCrossX() - @toMultiplicityDist() * angle.cos()

	@computed \
	toMultiplicityY : ->
		angle = @calcMultiplicityAngle @toCrossAngle(), @toIndicator()
		@toCrossY() - @toMultiplicityDist() * angle.sin()

	@computed \
	pathMode : ->
		angle = @fromCrossAngle()
		if -90 < angle < 90 then 'rev' else 'def'

	@computed \
	pathLength : ->
		@fromX(); @fromY(); @toX(); @toY()
		@pathElement().getTotalLength()

	OFFSET_FACTOR = 1.3

	@computed \
	fromOffset : ->
		diff = ((@fromX() - @fromCrossX()).sqr() +
			(@fromY() - @fromCrossY()).sqr()).sqrt() * OFFSET_FACTOR

		if @fromIsThick() && 30 < @fromCrossAngle().abs() < 150
			diff *= OFFSET_FACTOR

		if @pathMode() == 'rev'
			@pathLength() - diff
		else diff
	
	@computed \
	toOffset : ->
		diff = ((@toX() - @toCrossX()).sqr() +
			(@toY() - @toCrossY()).sqr()).sqrt() * OFFSET_FACTOR

		if @pathMode() == 'def'
			@pathLength() - diff
		else diff

module.exports = ClassDiagramViewModel