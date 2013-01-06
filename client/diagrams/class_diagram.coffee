Base          = require 'libs/base_mvm'
Diagram       = require './diagram'
countTextSize = require 'libs/count_text_size'

class ClassDiagram extends Diagram
	@observable 'name', 'width', 'height', 'shiftX', 'shiftY'
	@observableArray 'essentials', 'relations'

	constructor : ->
		super

		@name 'Undefined'

class Essential extends Base
	@observable 'name', 'posX', 'posY'
	@observableArray 'relations', 'stereotypes'

	constructor : ->
		super

		@parts = [
			@header     = new Header
			@attributes = new Section
			@operations = new Section
		]

		@header.height.subscribe (v) =>
			@attributes.posY v
			@operations.posY @attributes.height() + v

		@attributes.height.subscribe (v) =>
			@operations.posY v + @header.height

		@width.subscribe @operations.width
		@width.subscribe @attributes.width

	@computed \
	width : ->
		@parts.map((part) -> part.minWidth()).min()

	@computed \
	height : ->
		@header.height() + @attributes.height() + @operations.height()

class Header extends Base
	@observable 'width', 'name'

	MIN_TEXT_PADDING : 3

	@computed \
	height : ->
		minHeight = @MIN_TEXT_PADDING * 2 + countTextSize(@name).height

	@computed
	posXName : ->
		(@width - countTextSize(@name).width) / 2

	@computed \
	posYName : ->
		@height() / 2
	
	@computed \
	minWidth : ->
		@MIN_TEXT_PADDING * 2 + countTextSize(@text).width

class Section extends Base
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
		
class Member extends Base
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

class Attribute extends Member
class Operation extends Member
	@observableArray 'params'

	constructor : ->
		super
		@params []

class Param extends Base
	@observable 'name', 'type'

	constructor : ->
		super

		@name = ''
		@type = 'void'

class Relationship extends Base
class Association extends Relationship
class Aggregation extends Relationship
class Composition extends Relationship
class Generalization extends Relationship
class Realization extends Relationship
class Dependency extends Relationship

module.exports = ClassDiagram