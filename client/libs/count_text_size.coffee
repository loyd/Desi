require 'domReady!'

isTmplInclude = ///
	<!--\s*ko\s+template\s*:\s*
	(?:.*?name\s*:\s*)?(['"])(.*?)\1.*?-->
///gi

explainTmpl = (name) ->
	text = document.querySelector("##{name}").text
		.replace isTmplInclude, (str, b, tmplName) -> explainTmpl(tmplName)

div = document.createElement 'div'
div.dataset.bind = 'stopBindings: true'
div.innerHTML = explainTmpl('edit-tmpl')

do ($ = div.style) ->
	$.visibility = 'hidden'
	$.position   = 'absolute'
	$.top        = '0px'
	$.left       = '0px'
	$.width      = '1px'
	$.height     = '1px'

div.querySelector('svg').setAttribute('viewBox', '0 0 1 1')
document.body.appendChild div

cache = {}

count = (selector, content) ->
	if selector of cache
		text = cache[selector]
	else
		text = div.querySelector selector
		if text.tagName != 'text'
			text = text.querySelector('text')

		cache[selector] = text

	text.textContent = content
	bbox = text.getBBox()
	
	width  : bbox.width + 6 # fix incorrect letter spacing
	height : bbox.height

count.specify = (baseSelector) ->
	(selector, content) ->
		if arguments.length == 1
			count "#{baseSelector}", selector
		else
			count "#{baseSelector} #{selector}", content

module.exports = count