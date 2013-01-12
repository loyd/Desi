{BaseModel} = require 'libs/base_class'

class ClassDiagramModel extends BaseModel
	@observable 'name'
	@observableArray 'essentials', 'relations'

	constructor : ->
		@name 'undefined'

class EssentialModel extends BaseModel
	@observable 'posX', 'posY', 'name'
	@observableArray 'stereotypes', 'attributes', 'operations', 'relationships'

class MemberModel extends BaseModel
	@observable 'name', 'type', 'isStatic'
	@observableArray 'stereotypes'
	
	@observable 'visibility' : (val) ->
		val of visibilities

	@visibilities = visibilities =
		public    : '+'
		private   : '-'
		protected : '#'
		package   : '~'
		derived   : '/'

	constructor : ->
		@name 'undefined'
		@type 'void'
		@visibility visibilities.public
		@isStatic no

class AttributeModel extends MemberModel

class OperationModel extends MemberModel
	@observableArray 'params'

class ParamModel extends BaseModel
	@observable 'name', 'type'

class RelationshipModel extends BaseModel
	for prop in ['posMode', 'essential', 'indicator']
		@observable "#{prop}From"
		@observable "#{prop}To"

	validMultiplicity = /^(?:\d+\.{2})?(?:\d+|\*)$/
	@observable 'multiplicityFrom', 'multiplicityTo', (val) ->
		validMultiplicity.test val

	@observableArray 'stereotypes'

class AssociationModel extends RelationshipModel
class AggregationModel extends RelationshipModel
class CompositionModel extends RelationshipModel
	@observable 'multiplicityFrom' : (val) ->
		val in ['0', '0..1']

class GeneralizationModel extends RelationshipModel
class RealizationModel extends RelationshipModel
class DependencyModel extends RelationshipModel

module.exports = {
	ClassDiagramModel, EssentialModel, MemberModel, AttributeModel,
	OperationModel, ParamModel, RelationshipModel, AssociationModel,
	AggregationModel, CompositionModel, GeneralizationModel, RealizationModel,
	DependencyModel, RelationshipGoalModel, 
}