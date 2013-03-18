BaseViewModel = require 'libs/base_view_model'
Members       = require './members'
Synchronizer  = require 'libs/synchronizer'
countTextSize = require('libs/count_text_size').specify('.essential .header')
ko            = require 'ko'

MIN_HEADER_PADDING = 8 # [unit]

class EssentialViewModel extends BaseViewModel

	constructor : (@sync) ->
		@name  = sync.observer 'name'
		@posX  = sync.observer 'posX'
		@posY  = sync.observer 'posY'
		@color = sync.observer 'color'
		@isAbstract = sync.observer 'isAbstract'

		@attributes = sync.observer 'attributes',
			classAdapter : Members.AttributeViewModel
		@attributes.subscribe => do @placeAttributes
		do @placeAttributes

		@operations = sync.observer 'operations',
			classAdapter : Members.OperationViewModel
		@operations.subscribe => do @placeOperations
		do @placeOperations

		@relationships = sync.observer 'relationships'
		@stereotypes   = sync.observer 'stereotypes'

		@isMoved   = ko.observable no
		@isChosen  = ko.observable no

		super

	@computed \
	nameSize : ->
		countTextSize '.name', @name()

	@computed \
	stereotypeSize : ->
		countTextSize '.stereotype', @stereotypeText()

	@computed \
	centerX : ->
		@posX() + @width() / 2
	
	@computed \
	centerY : ->
		@posY() + @height() / 2

	@computed \
	width : ->
		w = Math.max(
			MIN_HEADER_PADDING * 2 + @stereotypeSize().width
			MIN_HEADER_PADDING * 2 + @nameSize().width
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
		attr = new Members.AttributeViewModel sync
		@attributes.push attr

	removeAttribute : (attr) ->
		@attributes.delete attr

	addOperation : ->
		sync = new Synchronizer @spec.data.operations.item
		oper = new Members.OperationViewModel sync
		@operations.push oper

	removeOperation : (oper) ->
		@operations.delete oper

	addRelationship : (rel) ->
		sync = new Synchronizer @spec.data.relationships.item
		ptr  = sync.observer()
		ptr rel.ref()
		@relationships.push ptr

	removeRelationship : (rel) ->
		@relationships.delete (ptr) ->
			ptr.deref() is rel

	addStereotype : (stereotype) ->
		sync = new Synchronizer @spec.data.stereotypes.item
		str  = sync.observer()
		str stereotype
		@stereotypes.push str

	#### Header section
	
	@computed \
	headerHeight : ->
		MIN_HEADER_PADDING * 2 + @nameSize().height +
			MIN_HEADER_PADDING * @stereotypes().length * 3/2

	@computed \
	namePosX : ->
		@width() / 2

	@computed \
	namePosY : ->
		@headerHeight() - MIN_HEADER_PADDING - @nameSize().height / 2

	@computed \
	stereotypePosY : ->
		MIN_HEADER_PADDING + @stereotypeSize().height / 2

	@computed \
	stereotypeText : ->
		"<<#{@stereotypes()[0]?() || ''}>>"

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
	attributesPosY : -> @headerHeight()

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

module.exports = EssentialViewModel