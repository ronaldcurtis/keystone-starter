module.exports = (err) ->
	
	res = this.res
	req = this.req

	res.status(500)

	sendJSON = (data) ->
		if !data
			return res.send()
		else
			if (typeof data != 'object' || data instanceof Error)
				data = { error: data }
			res.json(data)

	sendHTML = (data) ->
		res.render('500', { error: data })

	if req.wantsJSON
		sendJSON(err)
	else
		sendHTML(err)
