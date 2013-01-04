Base    = require 'libs/base_mvm'
Diagram = require './diagram'
{observable, observableArray} = require 'ko'

class ClassDiagram extends Diagram
	constructor : ->
		super

		@name   = observable ''
		@width  = observable 0
		@height = observable 0

		@essentials = observableArray []
		@relations  = observableArray []

class Essential extends Base
	constructor : ->
		super

		@name     = observable ''
		@position =
			x : observable 0
			y : observable 0

		@size =
			width  : observable 0 
			height : observable 0
		
		@operations  = observableArray []
		@attributes  = observableArray []
		@relations   = observableArray []
		@stereotypes = observableArray []

	place : (x, y) ->
		@position.x x
		@position.y y

	move : (dX, dY) ->
		@position.x += dX
		@position.y += dY

	transform : (dW, dH) ->
		@size.width  += dW
		@size.height += dH

class Member extends Base
	@visibilities = visibilities =
		public    : '+'
		private   : '-'
		protected : '#'
		package   : '~'
		derived   : '/'

	constructor : ->
		super

		@name       = observable ''
		@type       = observable 'void'
		@visibility = observable visibility.public
		@isStatic   = observable no

class Attribute extends Member
class Operation extends Member
	constructor : ->
		super

		@params = observableArray []

class Param extends Base
	constructor : ->
		super

		@name = observable ''
		@type = observable ''

class Relationship extends Base
	constructor : (from, to) ->
		super

		@points = []

class Association extends Relationship
class Aggregation extends Relationship
class Composition extends Relationship
class Generalization extends Relationship
class Realization extends Relationship
class Dependency extends Relationship

module.exports = ClassDiagram