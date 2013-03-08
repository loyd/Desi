BaseViewModel         = require 'libs/base_view_model'
EssentialViewModel    = require './essential'
RelationshipViewModel = require './relationship'
Synchronizer          = require 'libs/synchronizer'
onresize              = require 'libs/onresize'
ko                    = require 'ko'

SCALE_DIFF = 0.15
MIN_SCALE  = 0.45
MAX_SCALE  = 3

class ClassDiagramViewModel extends BaseViewModel
	viewRoot : '.class-diagram'
	
	main = document.querySelector '#main'

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
		
		@fakeRelationship          = ko.observable null
		@fakeEssential             = ko.observable null
		@fakeRelationshipIsVisible = ko.observable no
		@fakeEssentialIsVisible    = ko.observable no

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

		onresize main, (=>
			do @refreshSizes if @isChosen
		).debounce()

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
		bbox = main.getBoundingClientRect()
		@width  bbox.width
		@height bbox.height
		return

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
		{left, top} = main.getBoundingClientRect()
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
		{left, top} = main.getBoundingClientRect()
		scaleFactor = @scaleFactor()
		baseShiftX = posX() - (event.clientX - left) / scaleFactor
		baseShiftY = posY() - (event.clientY - top)  / scaleFactor

		isMoving = no
		mouseMove = ((e) =>
			unless isMoving
				isMoving = yes
				ess.isMoved yes
				@openMenu null
				@chooseEssential null

			posX baseShiftX + (e.clientX - left) / scaleFactor
			posY baseShiftY + (e.clientY - top)  / scaleFactor

			return
		).debounce()

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
		if MIN_SCALE <= newFactor <= MAX_SCALE
			@scaleFactor newFactor

	@computed \
	viewBox : ->
		scaleFactor = @scaleFactor()
		posX = @originX().toFixed(2)
		posY = @originY().toFixed(2)
		uuWidth  = (@width()  / scaleFactor).toFixed(2)
		uuHeight = (@height() / scaleFactor).toFixed(2)
		"#{posX} #{posY} #{uuWidth} #{uuHeight}"

	@computed \
	bgSize : ->
		value = 1.5 * @scaleFactor()
		"#{value}mm #{value}mm"

	@computed \
	bgPosition : ->
		scaleFactor = @scaleFactor()
		posX = (-@originX() * scaleFactor).toFixed(2)
		posY = (-@originY() * scaleFactor).toFixed(2)
		"#{posX}px #{posY}px"

	nameWheelEvent = ['wheel', 'mousewheel'].scan((name) ->
		('on' + name) of document) || 'MozMousePixelScroll'

	@delegate(nameWheelEvent) (el, event) ->
		sign = (-event.deltaY || event.detail || event.wheelDelta).sign()
		
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

		mouseMove = ((e) =>
			@shift(e.clientX - prevX, e.clientY - prevY)
			prevX = e.clientX
			prevY = e.clientY
			unless @isMoved
				@isMoved = yes
				if @openMenu() == 'creating'
					@openMenu null
		).debounce()

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

		{left, top} = main.getBoundingClientRect()
		scaleFactor = @scaleFactor()
		someX = @originX() - fakeEss.width() / 2
		someY = @originY() - fakeEss.height() / 2

		menuIsClosed = no
		mouseMove = ((e) =>
			unless menuIsClosed
				@openMenu null
				menuIsClosed = yes

			fakeEss.posX someX + (e.clientX - left) / scaleFactor
			fakeEss.posY someY + (e.clientY - top) / scaleFactor
		).debounce()

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

	@computed \
	essentialMenuWidth : ->
		calcMenuWidth @essentialMenuElement()

	@computed \
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

module.exports = ClassDiagramViewModel