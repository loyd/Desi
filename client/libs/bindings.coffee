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

		value = unwrap accs()
		if typeof value == 'object'
			for className, flagAccs of value
				flag  = unwrap flagAccs()
				index = classes.indexOf(" #{className} ")

				continue if flag == Boolean(~index)
				if flag
					classes += "#{className} "
				else
					classes = classes.replace " #{className} ", ' '
		else
			value = String value || ''
			classes = classes.replace " #{elem.__ko__cssValue} ", ' '
			classes += value
			elem.__ko__cssValue = value

		elem.setAttribute 'class', classes.trim()
}

register 'xlinkhref', no, {
	update : (elem, accs) ->
		value = unwrap accs()
		elem.setAttributeNS('http://www.w3.org/1999/xlink', 'href', value)
}

register 'stopBindings', no, {
	init : ->
		controlsDescendantBindings : on
}

'x x1 x2 y y1 y2 width height d id startOffset transform viewBox'.words()
.forEach (attr) ->
	register attr, no, {
		update : (elem, accs) ->
			elem.setAttribute attr, unwrap accs()
	}

['backgroundPosition', 'backgroundSize'].forEach (style) ->
	register style, no, {
		update : (elem, accs) ->
			elem.style[style] = unwrap accs()
	}