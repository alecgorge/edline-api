fs 		= require 'fs'
path	= require 'path'
mkdirp	= require 'mkdirp'
logger	= require 'winston'

class EdlineFile
	@fetch_file: (cache, file, request, cb) ->
		name = file.substring(7).replace(/([^a-zA-Z0-9-_\/.]+)/g, '-').replace('+', ' ')
		cache_name = ['cache', '__files__'].concat(name.split('/'))

		q = path.resolve('cache/__files__/' + name)

		logger.debug "Does #{q} exist? Checking..."
		fs.exists q, (exists) ->
			_ret = () ->
				cb file: cache_name.join('/')

			logger.debug "...done. #{exists}"
			if not exists
				mkdirp cache_name.slice(0, -1).join('/'), 0o0777, (err) ->
					throw err if err

					outputFile = fs.createWriteStream q
					outputFile.on 'close', (err) ->
						logger.debug "...done!"
						_ret()

					logger.debug "Downloading file..."
					request({
						uri: 'https://www.edline.net/' + file,
						followRedirect: true
					}).pipe(outputFile)
			else
				_ret()

module.exports = EdlineFile
