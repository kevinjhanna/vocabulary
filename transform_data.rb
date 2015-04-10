require "uri"
require "json"
require "nokogiri"
require "net/http/persistent"
require "redic"

redis = Redic.new

class Translator
  URL = "http://www.wordreference.com/es/translation.asp?tranword=%s"

  def self.http
    @http ||= Net::HTTP::Persistent.new("keywords")
  end

  def self.translate(term)
    uri = URI.parse(URL % URI.escape(term))

    res = http.request(uri)

    raise RuntimeError.new("#{res.code} when requesting #{uri}") if res.code.to_i / 100 == 5

    doc = Nokogiri::HTML(res.body)

    match = doc.at_xpath("//td[@class='ToWrd']/text()")

    return nil if match.nil?

    match.text.split(",").first.strip
  end
end

data =  Hash.new { |hash, key| hash[key] = [] }
redis.call("ZRANGE", "Counts", "-100", "-1", "WITHSCORES").each_slice(2) do |word, score|

  tries = 2
  begin
     translation = Translator.translate(word) if tries > 0
     puts "#{word} => #{translation} | #{score}"
     data[translation] << word

   rescue RuntimeError => e
     tries -= 1
     puts "Failed... #{e}"
     sleep 3
     retry
   end
end

output_data = []

data.each do |key, value|
  output_data << { "translation" => key, "words" => value, "score" => ""}
end

File.open("translations2.json", 'w') do |output|
  output.write(output_data.to_json)
end
