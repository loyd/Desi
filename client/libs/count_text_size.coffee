require 'domReady!'

isTmplInclude = ///
	<!--\s*ko\s+template\s*:\s*
	(?:.*?name\s*:\s*)?(['"])(.*?)\1.*?-->
///gi

explainTmpl = (name) ->
	text = document.querySelector("##{name}").text
		.replace isTmplInclude, (str, b, tmplName) -> explainTmpl(tmplName)

div = document.createElement 'div'
div.innerHTML = explainTmpl('edit-tmpl')

do ($ = div.style) ->
	$.visibility = 'hidden'
	$.position   = 'absolute'
	$.top        = '0px'
	$.left       = '0px'
	$.width      = '1px'
	$.height     = '1px'

document.body.appendChild div

cache = {}

module.exports = (selector, content) ->
	if selector of cache
		text = cache[selector]
	else
		text = div.querySelector selector
		if text.tagName != 'text'
			text = text.querySelector 'text'

		cache[selector] = text

	text.textContent = content
	text.getBBox() || { width : 0, height : 0 }
