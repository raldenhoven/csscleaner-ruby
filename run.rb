require 'mechanize'
require 'uri'
require 'hpricot'
require 'open-uri'
require 'yaml'

agent = Mechanize.new { |agent|
  agent.user_agent_alias = 'Mac Safari'
}

begin
  puts "scrapi the scraper"
  
  domain  = ARGV[0]
  levels = ARGV[1].to_i + 1 
  cssfile = ARGV[2]
  loopcounter = 0

  main_url = "http://"+domain+"/"

  urls = [main_url]
  scanned_urls = []

  until loopcounter == levels do 
    loopcounter += 1
    new_urls = []
    urls.each do |url|
      unless scanned_urls.include? url
        puts ""
        scanned_urls.push(url)
        puts "Scanning: #{url}"
        puts "-----------------------------"
        begin
          html = agent.get(url)
          html.search('a').each do |link| 
            unless link['href'].nil?
              if link['href'].include? domain
                link_final = link['href'].split("#").first
                new_urls.push(link_final)
                puts link_final
              elsif (link['href'] =~ URI::DEFAULT_PARSER.regexp[:ABS_URI]).nil? 
                part = link['href'].split("#").first
                unless part.nil?
                  link_final = "http://" + domain + part
                  new_urls.push(link_final)
                  puts link_final
                end
              end
            end
          end
          puts "----------------------------"
        rescue 
          puts "ResponseCodeError - Code: #{$!}"
        end
      end
    end
    urls = (urls+new_urls).uniq
  end
  puts "---------------------------------"
  puts "Searching for unused CSS"
  
  content = ""
  css_sourcefile =  agent.get(cssfile).content.to_s
  css_sourcefile.each_line {|line| content << line}

  # process our css file into a nice array of selectors
  content.gsub!(/\/\*.*?\*\//m, "") # strip the comments
  content.gsub!(/\{.*?\}/m, "") # strip the definitions
  content.gsub!(",", "\r\n") # one selector per line.
  content.gsub!(/^\s+$/, "") # strip lines containing just whitespace
  content.gsub!(/[\r\n]+/, "\n") # just one new line, thanks.
  content.gsub!(/:.*$/, "")
  selectors = content.split("\n").map {|s| s.strip}.uniq # no trailing whitespace in our array, pleasr
  
  results = Hash.new

  urls.each do |url|
    begin
      puts "Parsing #{url}"
      doc = agent.get(url) 
      # Iterate over each selector in cssfile and put the count of them into hash
      selectors.each do |selector|
        begin
          if results.has_key?(selector)
            results[selector] = results[selector] + doc.search(selector).size
          else
            results[selector] = doc.search(selector).size
          end
        rescue
          puts "Not a valid css selector #{selector} removing from selectors"
          selectors.delete(selector)
        end
      end
    rescue
      puts "ResponseCodeError - Code: #{$!}"
    end
  end
  
  puts "-------------"
  puts "The following selectors are NOT used in #{cssfile}"
  puts "-------------"
  
  # print all the selectors that are not used anywhere.
  result_final = results.sort_by {|sel, count| sel}.select {|sel, count| count.eql? 0}
  result_final.each do |selector, count|
    puts selector
  end

  puts "--------------------"
  puts "Finished with #{domain}"
  puts "Finished scraping #{levels - 1} levels"
  puts "Scraped #{urls.count} urls"
  puts "#{result_final.count} of #{selectors.count} selectors are unused (#{(result_final.count.to_f / selectors.count.to_f)*100} %)"
  puts "--------------------"
#rescue
  #puts "Usage: run.rb [domain:string] [levels:int] [cssfile:location]"
end
