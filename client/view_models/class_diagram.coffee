{BaseViewModel} = require 'libs/base_class'
countTextSize   = require 'libs/count_text_size'
M               = require 'models/class_diagram'

class ClassDiagramViewModel extends BaseViewModel
	@model M.ClassDiagramModel
	@adopted 'name'
	@observable 'shiftX', 'shiftY'
	@observableArray 'essentials', 'relationships'

	constructor : ->
		super

		@shiftY 0
		@shiftX 0

	addEssential : (x, y) ->
		ess = new EssentialViewModel
		ess.posX x
		ess.poxY y
		@essentials.push ess

class EssentialViewModel extends BaseViewModel
	@model M.EssentialModel
	@viewRoot '.essential'
	@adopted 'name', 'posX', 'posY'
	@observableArray 'relationships', 'stereotypes'

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

	@delegate('click', '.btn-add-attribute') \
	addAttribute : ->
		attr = new AttributeViewModel
		@attributes.push attr

	@delegate('click', '.btn-rm-attribute') \
	removeAttribute : (attr) ->
		@attributes.remove attr

	@delegate('click', '.btn-add-operation') \
	addOperation : ->
		oper = new OperationViewModel
		@operations.push oper

	@delegate('click', '.btn-rm-operation') \
	rmOperation : (oper) ->
		@operations.remove oper

class HeaderViewModel extends BaseViewModel
	@observable 'width', 'name'

	MIN_TEXT_PADDING : 3

	@computed \
	height : ->
		minHeight = @MIN_TEXT_PADDING * 2 + countTextSize(@name).height

	@computed \
	posXName : ->
		#(@width - countTextSize(@name).width) / 2
		@width() / 2

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
	@model M.MemberModel
	@observable 'isStatic', 'name', 'type', 'posY', 'visibility'

	constructor : ->
		super

		@name ''
		@type 'void'
		@visibility visibilities.public
		@isStatic no

class AttributeViewModel extends MemberViewModel
	@model M.AttributeModel

class OperationViewModel extends MemberViewModel
	@model M.OperationModel
	@observableArray 'params'

	constructor : ->
		super
		@params []

class ParamViewModel extends BaseViewModel
	@model M.ParamModel
	@observable 'name', 'type'

	constructor : ->
		super

		@name = ''
		@type = 'void'

class RelationshipViewModel extends BaseViewModel
	@model M.RelationshipModel

class AssociationViewModel extends RelationshipViewModel
	@model M.AssociationModel

class AggregationViewModel extends RelationshipViewModel
	@model M.AggregationModel

class CompositionViewModel extends RelationshipViewModel
	@model M.CompositionModel

class GeneralizationViewModel extends RelationshipViewModel
	@model M.GeneralizationModel

class RealizationViewModel extends RelationshipViewModel
	@model M.RealizationModel

class DependencyViewModel extends RelationshipViewModel
	@model M.DependencyModel

module.exports = ClassDiagramViewModel