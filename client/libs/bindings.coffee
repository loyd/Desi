ko = require 'ko'

register = (name, allowVirtual, cnf) ->
	ko.bindingHandlers[name] = cnf
	ko.virtualElements.allowedBindings[name] = true if allowVirtual

register 'section', yes, do ->
	tmplBinding = ko.bindingHandlers['template']

	wrap = (what) -> ->
		section   = ko.utils.unwrapObservable arguments[1]()
		viewModel = arguments[3]
		arguments[1] = ->
			name : section.sectionTmpl
			data : section
			if   : viewModel.activeSection() == section
		
		what.apply this, arguments

	init   : wrap(tmplBinding.init),
	update : wrap(tmplBinding.update)

register 'translate', no, {
	update : (elem, accs) ->
		value = ko.utils.unwrapObservable accs()
		elem.setAttribute 'transform', "translate:(#{value.x}, #{value.y})"
}

register 'translateY', no, {
	update : (elem, accs) ->
		value = ko.utils.unwrapObservable accs()
		elem.setAttribute 'transform', "translate:(0, #{value})"
}

register 'translateX', no, {
	update : (elem, accs) ->
		value = ko.utils.unwrapObservable accs()
		elem.setAttribute 'transform', "translate:(#{value}, 0)"
}