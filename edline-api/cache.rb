
require 'json'
require 'digest/md5'
require 'rubygems'
require 'couchbase'

class Cache
	USER_DURATION 		= 60 * 60 * 24 * 7 * 2 	# 2 weeks
	CLASS_DURATION 		= 60 * 60 * 8 			# 8 hours
	CLASS_URL_DURATION 	= 60 * 60 * 24 * 7 * 2 	# 2 weeks
	ITEM_URL_DURATION 	= 60 * 60 * 24 * 7 * 2 	# 2 weeks
	ITEM_DURATION 		= 60 * 60 * 2			# 2 hours
	REPORT_DURATION		= 60 * 60 * 2			# 2 hours
	SHOULD_FLATTEN 		= true
	SHOULD_CACHE 		= true

	def initialize(cache_dir, length)
		@cache_dir = cache_dir
		@duration = length

		@client = Couchbase.new "http://alecgorge.com:8091/pools/default/buckets/edline"
		@client.quiet = true
	end

	# kept for bc only
	def path(*name)
		p = File.join(@cache_dir, *name) + ".txt"

		if Cache::SHOULD_FLATTEN
			p = name.join("/")
			p = Digest::MD5.new << p
			p = p.to_s << ".txt"

			# organize into folders so we don't end up with 100k+ files in one dir
			d = File.join(@cache_dir, p[0,2])

			if !File.directory?(d)
				FileUtils.mkdir_p(d, :mode => 0777)
			end

			p = File.join(d, p)
		end

		p
	end

	def key(*name)
		p = name.join(".")
		#p = Digest::MD5.new << p
		#p.to_s
		p
	end

	def get(name, default = nil, length = @duration)
		name = [name] unless name.kind_of? Array

		return default if not SHOULD_CACHE

		v = @client.get self.key(*name)

		return v unless v == nil
		return default
	end

	def set(name, value, length = @duration)
		name = [name] unless name.kind_of? Array
		
		v = @client.set(self.key(*name), value, :ttl => length)

		return value
	end
end
