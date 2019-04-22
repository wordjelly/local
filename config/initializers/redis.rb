redis_host = ENV["REDIS_URL"] || "localhost:6379"
$redis = Redis.new(url: ENV["REDIS_URL"])
$redis.set("first_key","first_value")
if Rails.env.development?
	puts "flushing db as we are in development."
	$redis.flushdb
end
