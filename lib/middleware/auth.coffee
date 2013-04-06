Messages = require '../messages.coffee'

module.exports = ->
	return (req, res, next) ->
		if req.body.u? and req.body.p?
			return next()

		res.json 401, Messages.no_auth_vars()
