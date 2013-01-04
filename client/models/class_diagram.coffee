BaseModel    = require 'libs/base_model'
DiagramModel = require './diagram'
{observable, observableArray} = require 'ko'

class ClassDiagramModel extends DiagramModel
	constructor : ->
		super

		@name   = observable ''
		@width  = observable 0
		@height = observable 0

		@essentials = observableArray []
		@relations  = observableArray []

class EssentialModel extends BaseModel
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

class MemberModel extends BaseModel
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

class AttributeModel extends MemberModel
class OperationModel extends MemberModel
	constructor : ->
		super

		@params = observableArray []

class ParamModel extends BaseModel
	constructor : ->
		super

		@name = observable ''
		@type = observable ''

class RelationshipModel extends BaseModel
	constructor : (from, to) ->
		super

		@points = []

class AssociationModel extends RelationshipModel
class AggregationModel extends RelationshipModel
class CompositionModel extends RelationshipModel
class GeneralizationModel extends RelationshipModel
class RealizationModel extends RelationshipModel
class DependencyModel extends RelationshipModel

module.exports = ClassDiagramModel