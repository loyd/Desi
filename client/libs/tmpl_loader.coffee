load = (tmpl, cb) ->
	xhr = new XMLHttpRequest
	xhr.open 'GET', tmpl.src, true
	xhr.onreadystatechange = -> 
		if xhr.readyState == 4
			if xhr.status == 200
				tmpl.text = xhr.responseText
			else
				console.error "Failed to load resource:" +
					"the server responded with a status of #{xhr.status}"
			do cb

	xhr.send null

DOMLoaded = document.readyState in ['interactive', 'complete']
document.addEventListener 'DOMContentLoaded', (-> DOMLoaded = yes), off
module.exports = run = (next) ->
	unless DOMLoaded
		return addEventListener 'DOMContentLoaded', ->
			DOMLoaded = yes
			do run
		, off

	list = document.querySelectorAll(
		'script[type="text/html"],' +
		'script[type="image/svg+xml"]'
	)

	count = list.length
	cb = -> setTimeout next, 0 unless --count
	load(tmpl, cb) for tmpl in list
