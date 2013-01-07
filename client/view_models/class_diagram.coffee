{BaseViewModel}  = require 'libs/base_class'
DiagramViewModel = require './diagram'
countTextSize    = require 'libs/count_text_size'

class ClassDiagramViewModel extends DiagramViewModel
	@observable 'name', 'width', 'height', 'shiftX', 'shiftY'
	@observableArray 'essentials', 'relations'

	constructor : ->
		super

		@name 'Undefined'

class EssentialViewModel extends BaseViewModel
	@observable 'name', 'posX', 'posY'
	@observableArray 'relations', 'stereotypes'

	constructor : ->
		super

		@parts = [
			@header     = new HeaderViewModel
			@attributes = new SectionViewModel
			@operations = new SectionViewModel
		]

		@header.height.subscribe (v) =>
			@attributes.posY v
			@operations.posY @attributes.height() + v

		@attributes.height.subscribe (v) =>
			@operations.posY @header.height() + v

		@width.subscribe @operations.width
		@width.subscribe @attributes.width

	@computed \
	width : ->
		@parts.map((part) -> part.minWidth()).min()

	@computed \
	height : ->
		@header.height() + @attributes.height() + @operations.height()

class HeaderViewModel extends BaseViewModel
	@observable 'width', 'name'

	MIN_TEXT_PADDING : 3

	@computed \
	height : ->
		minHeight = @MIN_TEXT_PADDING * 2 + countTextSize(@name).height

	@computed \
	posXName : ->
		(@width - countTextSize(@name).width) / 2

	@computed \
	posYName : ->
		@height() / 2
	
	@computed \
	minWidth : ->
		@MIN_TEXT_PADDING * 2 + countTextSize(@text).width

class SectionViewModel extends BaseViewModel
	@observable 'width', 'posY'
	@observableArray 'data'

	constructor : ->
		super

		@visible no
		@data []

		@data.subscribe => do @defineDataPosY

	@computed \
	visible : {
		read : ->
			return 0 if @data().empty()
			@visible_

		write : (v) ->
			@visible_ = v
	}

	@computed \
	height : ->
		return 0 unless @visible()
		
		@data().reduce (sum, elem) ->
			sum + elem.height()
		, 0

	defineDataPosY : ->
		posY = 0
		for member in @data()
			member.posY posY
			posY += member.height()

	minWidth : ->
		(@data().map (elem) -> elem.width()).max()
		
class MemberViewModel extends BaseViewModel
	@observable 'isStatic', 'name', 'type', 'posY', 'visibility'

	@visibilities = visibilities =
		public    : '+'
		private   : '-'
		protected : '#'
		package   : '~'
		derived   : '/'

	constructor : ->
		super

		@name ''
		@type 'void'
		@visibility visibilities.public
		@isStatic no

class AttributeViewModel extends MemberViewModel
class OperationViewModel extends MemberViewModel
	@observableArray 'params'

	constructor : ->
		super
		@params []

class ParamViewModel extends BaseViewModel
	@observable 'name', 'type'

	constructor : ->
		super

		@name = ''
		@type = 'void'

class RelationshipViewModel extends BaseViewModel
class AssociationViewModel extends RelationshipViewModel
class AggregationViewModel extends RelationshipViewModel
class CompositionViewModel extends RelationshipViewModel
class GeneralizationViewModel extends RelationshipViewModel
class RealizationViewModel extends RelationshipViewModel
class DependencyViewModel extends RelationshipViewModel

module.exports = ClassDiagram