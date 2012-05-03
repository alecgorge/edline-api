
require './edline-api/user'

class EdlineFile
	def self.fetch_file (cache, file, user = nil)
		name = file[7..-1]
		cache_name = ['cache', '__files__'] + name.split('/')
		q = File.join(*cache_name)

		if !File.exists?(q)
			FileUtils.mkdir_p(File.join(cache_name[0..-2]), :mode => 0777)

			user = User.new(@username, @password, cache) if user == nil
			if !user.isPrimed
				user.prime_cookies

				user.user_homepage # no need to check if valid; it is assumed
								   # to be so if a class is being requested
			end

			file = user.client.get('https://www.edline.net' + file)

			File.open(q, "w+") { |f|
				f.write(file.content)
			}
		end

		return {
			'file' => cache_name.join('/')
		}
	end
end