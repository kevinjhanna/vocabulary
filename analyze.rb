require "nokogiri"
require "redic"
require "set"

redis = Redic.new
redis.call("FLUSHALL")

reject = Set.new

# File.open("output.txt", 'w') do |output|
#   output.write(redis.call("ZRANGEBYSCORE", "Counts", "0", "+inf", "WITHSCORES").join("\n"))
# end

File.foreach("reject.txt") do |line|
  reject.add(line.chomp!)
end

Dir["blogs/**/**/*.html"].each do |path|
  next if redis.call("SISMEMBER", "Seen", path) == "1"

  File.open(path) do |f|
    doc = Nokogiri::HTML(f)

    words = doc.text.gsub(/(\n|\t|\*|,|\.|")/, " ").gsub(/\s+/, " ").split

    words.map(&:downcase!)

    words.each do |word|
      next if word.length <= 2 || reject.include?(word)

      redis.call("ZINCRBY", "Counts", "1", word)
    end

    redis.call("SADD", "Seen", f.path)
  end

  leadboard = redis.call("ZRANGEBYSCORE", "Counts", "10", "+inf", "WITHSCORES")
  # puts redis.call("ZRANGEBYSCORE", "Counts", "0", "20", "WITHSCORES")
  # puts redis.call("ZCARD", "Counts")
  puts "--"
  puts leadboard
end
