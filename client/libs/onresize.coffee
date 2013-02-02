require 'domReady!'

cache = []

makeIframe = (parent, handlers) ->
	iframe = document.createElement 'iframe'
	iframe.style.position   = 'absolute'
	iframe.style.visibility = 'hidden'
	iframe.width  = '100%'
	iframe.height = '100%'
	
	pos = getComputedStyle(parent, null).getPropertyValue 'position'
	if pos == 'static'
		parent.style.position = 'relative'

	parent.appendChild iframe

	iframe.contentWindow.onresize = (event) ->
		handler event for handler in handlers
		return

addHandler = (elem, handler) ->
	for cached in cache when cached.elem is elem
		cached.handlers.push handler
		return

	handlers = [handler]
	cache.push { elem, handlers }

	makeIframe elem, handlers

module.exports = (elem, handler) ->
	if typeof elem == 'string'
		elem = document.querySelector elem

	if elem? && typeof handler == 'function'
		addHandler elem, handler