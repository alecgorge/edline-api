
class Messages
	def self.error(hash)
		{
			"result" => "error",
			"error" => hash
		}
	end

	def self.success(hash)
		{
			"result" => "success",
			"success" => hash
		}
	end

	def self.json
		{
			'Content-Type' => 'application/json'
		}
	end

	def self.no_auth_vars
		self.error({
			"msg" => "Missing username or password."
		})
	end
end

