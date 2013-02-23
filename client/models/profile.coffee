{extend, number, string, array, object, boolean} = require 'libs/model_dsl'
classDiagram = require './class_diagram'

profile = object {
	id : (number def: 0) # 0 - Ghost
	freePtrId : (number def: 1)
	login : (string test: /^\w+$/i)
	email : (string test: /^(\S+)@([a-z0-9-]+)(\.)([a-z]{2,4})(\.?)([a-z]{0,4})+$/i)
	pswHash : string
	diagrams : (array of: classDiagram)
}

module.exports = profile