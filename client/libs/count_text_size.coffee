require 'domReady!'

SVG_NS = 'http://www.w3.org/2000/svg'

svg = document.createElementNS SVG_NS, 'svg'

do ($ = svg.style) ->
	$.visibility = 'hidden'
	$.position   = 'absolute'
	$.top        = 0
	$.left       = 0

svg.width  = 1
svg.height = 1
svg.className = 'diagram class-diagram'

text = document.createElementNS SVG_NS, 'text'
text.x = text.y = 0

svg.appendChild text
document.body.appendChild svg

module.exports = (content) ->
	text.textContent = content
	text.getBBox() || { width : 0, height : 0 }
