ko           = require 'ko'
nativeEngine = ko.nativeTemplateEngine.instance

class TemplateEngine extends ko.templateEngine
	constructor : ->
		@allowTemplateRewriting = no
		@cache = {}

	W3_SVG = 'http://www.w3.org/2000/svg'
	textToSvg = (text) ->
		div  = document.createElement 'div'
		div.innerHTML = "<svg xmlns=\"#{W3_SVG}\">#{text}</svg>"
		ko.utils.makeArray div.childNodes[0].childNodes

	renderTemplateSource : (template, context, options) ->
		elem    = template.domElement
		{name}  = options
		{cache} = this

		cache[name] ?= switch elem.type || elem.dataset.type
			when 'text/html', undefined
				nativeEngine.renderTemplateSource(template, context, options)
			when 'image/svg+xml'
				template.nodes?() || textToSvg(template.text())
			else
				throw new Error "Incorrect or unsupported MIME-type of ##{name}"

		node.cloneNode(on) for node in cache[name]

module.exports = TemplateEngine