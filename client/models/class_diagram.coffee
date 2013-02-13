{extend, number, string, array, object, boolean} = require 'libs/model_dsl'

stereotype = object

visibilities =
	public    : '+'
	private   : '-'
	protected : '#'
	package   : '~'
	derived   : '/'

member = object {
	name : (string def: 'undefined')
	type : (string def: 'void')
	isStatic : (boolean def: no)
	stereotypes : (array of: stereotype)
	visibility : string
		in: visibilities
		def: visibilities.public
}

attribute = extend member

param = object {
	name : (string def: 'foo')
	type : (string def: 'void')
}

operation = extend member, {
	params : (array of: param)
}

validMultiplicity = /^(?:\d+\.{2})?(?:\d+|\*)$/
between0and9 = (v) -> 0 <= v <= 9

relationship = object {
	type : (string in: [
		'association', 'aggregation',
		'composition', 'generalization',
		'realization', 'dependency'
	])
	posModeFrom : (number valid: between0and9)
	posModeTo : (number valid: between0and9)
	indicatorFrom : string
	indicatorTo : string
	essentialFrom : essential
	essentialTo : essential
	multiplicityFrom : (string valid: (val) ->
		if @type is 'composition'
			val in ['0', '0..1']
		else
			val.test validMultiplicity
	)
	multiplicityTo : (string test: validMultiplicity)
	stereotypes : (array of: stereotype)
}

essential = object {
	posX  : number
	posY  : number
	name  : (string def: 'ClassName')
	color : (string def: 'white')
	stereotypes : (array of: stereotype)
	attributes : (array of: attribute)
	operations : (array of: operation)
}

classDiagram = object {
	title : (string def: 'Untitled')
	lastModified : number
	essentials : (array of: essential)
	relationships : (array of: relationship)
}

module.exports = classDiagram