puts "initializaing redis"
$redis = Redis.new
puts "initialized"
if Rails.env.production?
	puts "we are in production"
	exit(1)
	$redis = Redis.new(url: ENV["REDIS_URL"])
end

