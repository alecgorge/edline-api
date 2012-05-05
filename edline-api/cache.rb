
require 'json'
require 'digest/md5'

class Cache
	USER_DURATION 		= 60 * 60 * 24 * 7 * 2 	# 2 weeks
	CLASS_DURATION 		= 60 * 60 * 8 			# 8 hours
	CLASS_URL_DURATION 	= 60 * 60 * 24 * 7 * 2 	# 2 weeks
	ITEM_URL_DURATION 	= 60 * 60 * 24 * 7 * 2 	# 2 weeks
	ITEM_DURATION 		= 60 * 60 * 2			# 2 hours
	REPORT_DURATION		= 60 * 60 * 2			# 2 hours
	SHOULD_FLATTEN 		= true
	SHOULD_CACHE		= true

	def initialize(cache_dir, length)
		@cache_dir = cache_dir
		@duration = length
	end

	def path(*name)
		p = File.join(@cache_dir, *name) + ".txt"

		if Cache::SHOULD_FLATTEN
			p = name.join("/")
			p = Digest::MD5.new << p
			p = p.to_s << ".txt"
			p = File.join(@cache_dir, p)
		end

		p
	end

	def get(name, default = nil, length = @duration)
		name = [name] unless name.kind_of? Array

		f = self.path(*name)
		d = File.dirname(f)

		if !File.exists?(f) || !SHOULD_CACHE
			return default
		end

		if (Time.now - File.mtime(f)).to_i < length
			File.open(f, 'r') { |file|
				default = JSON.parse(file.read)["payload"]
			}
		else
			File.unlink(f)
		end

		return default
	end

	def set(name, value)
		name = [name] unless name.kind_of? Array

		f = self.path(*name)
		d = File.dirname(f)
		
		if !File.directory?(d)
			FileUtils.mkdir_p(d, :mode => 0777)
		end

		File.open(f, "w+") { |file|
			file.write({"payload" => value}.to_json)
		}

		return value
	end
end