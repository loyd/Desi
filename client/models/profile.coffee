{extend, number, string, array, object, boolean} = require 'libs/model_dsl'

diagramMeta = object {
	id : string
	title : (string def: 'Untitled')
	lastModified : number
	lastSynchronized : number
}

profile = object {
	freePtrId : (number def: 1)
	login : (string test: /^\w+$/i)
	email : (string test: /^(\S+)@([a-z0-9-]+)(\.)([a-z]{2,4})(\.?)([a-z]{0,4})+$/i)
	diagrams : (array of: diagramMeta)
}

module.exports = profile