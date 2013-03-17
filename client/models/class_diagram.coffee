{extend, number, string, array, object, boolean, pointer} = require 'libs/model_dsl'

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

relationship = object {
	type : (string in: [
		'association', 'aggregation',
		'composition', 'generalization',
		'realization', 'dependency'
	], def: 'association')
	level : (number def: 0)
	maxLevel : (number def: 0)
	fromIndicator : string
	toIndicator : string
	fromEssential : (pointer -> essential)
	toEssential : (pointer -> essential)
	fromMultiplicity : (string valid: (val) ->
		if @type is 'composition'
			val in ['0..1', '1']
		else
			val.test validMultiplicity
	)
	toMultiplicity : (string test: validMultiplicity)
	stereotypes : (array of: stereotype)
}

essential = object {
	posX : number
	posY : number
	name : (string def: 'ClassName')
	color : (string def: 'white')
	isAbstract : (boolean def: no)
	stereotypes : (array of: stereotype)
	attributes : (array of: attribute)
	operations : (array of: operation)
	relationships : (array of: (pointer -> relationship))
}

classDiagram = object {
	essentials : (array of: essential)
	relationships : (array of: relationship)
}

module.exports = classDiagram