
req = (require 'request').defaults
	followRedirect: false
	strictSSL: false
	headers:
		"User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 6_0 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10A5376e Safari/8536.25"

module.exports = req