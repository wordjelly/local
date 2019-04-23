puts "initializaing redis"
$redis = Redis.new
puts "initialized"
#host = Rails.env.production? ? ENV["REDIS_URL"] : "http://localhost:6379"
if Rails.env.production?
	puts "we are in production"
	$redis = Redis.new(url: ENV["REDIS_URL"])
end
#$redis.set("first_key","first_value")
#if Rails.env.development?
	#puts "flushing db as we are in development."
	#$redis.flushdb
#end
