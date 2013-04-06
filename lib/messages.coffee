
class Messages
	@error: (h) -> result: "error", error: h
	@success: (h) -> result: "success", success: h
	@json: (h) -> 'Content-Type': 'application/json'
	@no_auth_vars: (h) -> @error msg: "Missing username or password."

module.exports = Messages
