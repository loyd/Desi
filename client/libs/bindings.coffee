ko = require 'ko'

register = (name, allowVirtual, cnf) ->
	ko.bindingHandlers[name] = cnf
	ko.virtualElements.allowedBindings[name] = true if allowVirtual

unwrap = ko.utils.unwrapObservable

register 'section', yes, do ->
	tmplBinding = ko.bindingHandlers['template']
	vsblBinding = ko.bindingHandlers['visible']

	wrap = (what) -> ->
		sectionName = unwrap(arguments[1]()) + '-tmpl'
		viewModel   = arguments[3]
		arguments[1] = ->
			name : sectionName
			data : viewModel

		vsblBinding.update arguments[0], ->
			sectionName == viewModel.sectionTemplate()
		
		what.apply this, arguments

	init   : wrap(tmplBinding.init),
	update : wrap(tmplBinding.update)

register 'translate', no, {
	update : (elem, accs) ->
		value = unwrap accs()
		x     = unwrap value.x
		y     = unwrap value.y
		elem.setAttribute 'transform', "translate(#{x}, #{y})"
}

register 'translateY', no, {
	update : (elem, accs) ->
		value = unwrap accs()
		elem.setAttribute 'transform', "translate(0, #{value})"
}

register 'translateX', no, {
	update : (elem, accs) ->
		value = unwrap accs()
		elem.setAttribute 'transform', "translate(#{value}, 0)"
}

register 'bindElement', no, {
	init : (elem, accs) ->
		accs() elem
}

register 'svgcss', no, {
	update : (elem, accs) ->
		classes = " #{elem.getAttribute('class') || ''} "

		for className, flagAccs of unwrap(accs())
			flag  = unwrap flagAccs()
			index = classes.indexOf(" #{className} ")

			continue if flag == Boolean(~index)
			if flag
				classes += "#{className} "
			else
				classes = classes.replace " #{className} ", ' '

		elem.setAttribute 'class', classes.trim()
}