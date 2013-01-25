BaseViewModel = require 'libs/base_view_model'
countTextSize   = require 'libs/count_text_size'
Synchronizer    = require 'libs/synchronizer'
ko              = require 'ko'

class ClassDiagramViewModel extends BaseViewModel
	@viewRoot '.class-diagram'

	constructor : (@sync) ->
		super

		@shiftY = ko.observable 0
		@shiftX = ko.observable 0
		
		@essentials = sync.observer 'essentials',
			classAdapter : EssentialViewModel

		@relationships = sync.observer 'relationships',
			classAdapter : RelationshipViewModel

	@delegate('click') (t, event) ->
		{left, top} = @element().getBoundingClientRect()
		x = event.clientX - left
		y = event.clientY - top
		@addEssential x, y

	addEssential : (x, y) ->
		sync = new Synchronizer @spec.essentials.item
		ess = new EssentialViewModel sync
		ess.posX x
		ess.poxY y
		@essentials.push ess

class EssentialViewModel extends BaseViewModel
	@viewRoot '.essential'

	MIN_HEADER_PADDING = 3

	constructor : (@sync) ->
		super

		@name = sync.observer 'name'
		@posX = sync.observer 'posX'
		@posY = sync.observer 'posY'

		@attributes = sync.observer 'attributes',
			classAdapter : AttributeViewModel
		@attributes.subscribe => @placeAttributes

		@operations = sync.observer 'operations',
			classAdapter : OperationViewModel
		@operations.subscribe => @placeOperations

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
	
	haederHeight : ->
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
		super

		@posY       = ko.observable()
		@name       = sync.observer 'name'
		@type       = sync.observer 'type'
		@visibility = sync.observer 'visibility'
		@isStatic   = sync.observer 'isStatic'

class AttributeViewModel extends MemberViewModel

class OperationViewModel extends MemberViewModel
	constructor : (@sync) ->
		super

		@params = sync.observer 'params',
			classAdapter : ParamViewModel

class ParamViewModel extends BaseViewModel
	constructor : (@sync) ->
		super

		@name = sync.observer 'name'
		@type = sync.observer 'type'

module.exports = ClassDiagramViewModel