#crawler.rb

require 'nokogiri'
require 'open-uri'
require 'set'
require 'fileutils'
require_relative 'tree'
require_relative 'parser'

class Crawler

    attr_accessor :seed_url, :seed_name, :base_url
    attr_reader :link_tree


    def initialize(seed_url, base_url, seed_name)
        @seed_url = seed_url
        @seed_name = seed_name
        @base_url = base_url
    end

    #does not create file tree, parses and saves pages in files. not limited to a domain
    def crawl_without_tree
        crawl_no_tree(false)
    end

    
    #without setting up a file tree, crawls a domain and creates parsed files for each site
    def crawl_domain_without_tree
        crawl_no_tree(true)
    end

    #does not create file tree. does not parse file. prints out links only. created for homework turn-in
    def crawl_domain_without_tree_save_list_links
        seen = Set.new
        queue = []
        queue << @seed_url
        seen.add(@seed_url)
        counter = 0
        failed = 0
        File.delete("./#{seed_name}_visited_pages") if File.exists?("./#{seed_name}_visited_pages")
        file = File.new("#{seed_name}_visited_pages", "a")
        errors = []
        while queue.length > 0
            #Sleep to help prevent overloading a server
            sleep(0.1)
            #Show cli interaction of links in queue and queue length
            puts "\n\n\n"
            puts queue
            puts "\n\n\n"
            puts "Last Queue Length #{queue.length}"
            url = queue.shift
            puts "Current Queue Length #{queue.length}"
            puts "#{counter} page(s) cralwed, #{failed} page(s) failed"
            #open page, write the url name to file, parse all links on page, filter out those already seen, and the remaining to the queue
            begin
                html = open(url)
                doc = Nokogiri::HTML(html)
                file.write("#{url}\n")
                counter += 1
                children = parse_links_from_domian(doc).select{|child| !!seen.add?(child)}
                queue.concat(children)
            rescue => error
                errors << error
                file.write("#{url}  *****************FAILED WITH ERROR: #{error}*******************\n")
                failed += 1
            end
        end
        file.write("\n\nAttempted to crawl #{counter + failed} pages. #{counter} domain links successfully crawled. Failed to crawl #{failed} links.\n Errors encountered: #{errors}")
    end


    #given a seed site, creates file tree for a domain and saves data as hash from url to site's parsed file
    def crawl_and_parse
        @link_tree = LinkTree.new(@seed_url)
        self.link_tree.bf_traverse_and_construct(@seed_name){|doc| parse_links(doc)}
    end

    #creates file tree for a domain and saves data as hash from url to site's parsed file 
    def crawl_and_parse_domain
        @link_tree = LinkTree.new(@seed_url)
        self.link_tree.bf_traverse_and_construct(@seed_name){|doc| parse_links_from_domian(doc)}
    end

    #allow recrawling once url => file hash already established. 
    #could be optimized to recrawl only those which should be frequently crawled
    def recrawl_existing_tree
        FileUtils.rm_rf("./#{seed_name}_tree_crawl_pages")
        Dir.mkdir("#{seed_name}_tree_crawl_pages")
        failed = 0
        counter = 0
        errors = []
        for i in 1..self.link_tree.max_level do
            level_nodes = self.link_tree.nodes_at_level[i]
            level_nodes.each do |node|
                url = node.data.keys[0]
                puts "Parsing #{node.data}..."
                begin
                    html = open(url)
                    doc = Nokogiri::HTML(html)
                    counter += 1
                    file = File.new("./#{seed_name}_tree_crawl_pages/#{seed_name}_page_#{counter}", "a")
                    to_write = Parser.parse(doc)
                    file.write("\n#{url}\n\n\n#{to_write}\n")
                    file.close()
                    node.data = {url => file}
                rescue => error
                    errors << error
                    puts "#{url} FAILED TO PARSE: #{error}"
                    failed += 1
                    node.data = {url => nil}
                end
                puts "#{counter} pages crawled, #{failed} failures due to errors: #{errors}"
            end
        end
    end


    private
    #stops from having to re-use code for crawl_without tree domain vs not domain
    def crawl_no_tree(domain_limited)
        seen = Set.new
        queue = []
        queue << @seed_url
        seen.add(@seed_url)
        counter = 0
        failed = 0
        errors = []
        #create directory for pages
        if domain_limited
            FileUtils.rm_rf("./#{seed_name}_domain_pages")
            Dir.mkdir("#{seed_name}_domain_pages")
        else
            FileUtils.rm_rf("./#{@seed_name}_seed_pages")
            Dir.mkdir("#{@seed_name}_seed_pages")
        end
        while queue.length > 0
            children_added = 0
            #Sleep to help prevent overloading a server
            sleep(0.1)
            #Show cli interaction of links in queue and queue length
            puts "\n\n\n"
            puts queue
            puts "\n\n\n"
            puts "Children added last iteration: #{children_added}"
            url = queue.shift
            puts "Current Queue Length: #{queue.length}"
            puts "#{counter} page(s) cralwed, #{failed} page(s) failed"
            #open page, write the url name to new file, parse all links on page, filter out those already seen, and the remaining to the queue
            begin
                html = open(url)
                doc = Nokogiri::HTML(html)
                file = File.new("./#{seed_name}_domain_pages/#{seed_name}_page_#{counter}", "a")
                to_write = Parser.parse(doc)
                file.write("\n#{url}\n\n\n#{to_write}\n")
                counter += 1
                children = domain_limited ? parse_links_from_domian(doc).select{|child| !!seen.add?(child)} : parse_links(doc).select{|child| !!seen.add?(child)}
                queue.concat(children)
                children_added = children.length
            rescue => error
                errors << error
                # file.write("#{url}  *******FAILED WITH ERROR********\n")
                failed += 1
            end
            file.close
            
        end
        puts ("\n\nAttempted to crawl #{counter + failed} pages. #{counter} domain links successfully crawled. Failed to crawl #{failed} links due to the following errors: #{errors}.")
    end


    #ensures all links are from the same domain. Puts links in the proper format
    def parse_links_from_domian(doc)
        #get a list of links from the site from hrefs

       links = doc.css("a").map{|a| a['href']}.reject{|link| !link || !(link.start_with?(@base_url) || link.start_with?('/')) || link.start_with?("//")}
        #remove all data after #(which will link to the same site but fool a string comparator), then remove duplicates
        unique_links = links.map do |link|
            hash_index = link.split('').find_index('#')
            if link.end_with?('/')
                link = link.byteslice(0,link.length - 1)
            end
            if !!hash_index
                link.split('').slice(0...hash_index).join('')
            else
                link
            end
        end
        .uniq
        #add base URL to links
        unique_links.map{|ul| ul.start_with?("/") ? @base_url + ul : ul}
    end


    #does not ensure links are from the same domain. Attempts to put in proper format, but 
    #more optimization is needed to ensure this - there are still lots of bad links that get through
    def parse_links(doc)
        #get a list of links from the site from hrefs
        links = doc.css("a").map{|a| a['href']}.reject{|link| !link || link.start_with?("#")}
        #remove all data after #(which will link to the same site but fool a string comparator), then remove duplicates
        unique_links = links.map do |link|
            hash_index = link.split('').find_index('#')
            if link.end_with?('/')
                link = link.byteslice(0,link.length - 1)
            end
            if !!hash_index
                link.split('').slice(0...hash_index).join('')
            else
                #some anchors were coming back with a // prefix
                link.start_with?('//') ? 'https:' + link : link
            end
        end
        .uniq
        #add base URL to links without it
        unique_links.map{|ul| !ul.start_with?('http') ? @base_url + ul : ul}
        
    end

end



UD_URL = "http://www.ece.udel.edu"
seed_page = "University_Of_Delaware_ECE"

spider = Crawler.new(UD_URL, UD_URL, seed_page)
spider.crawl_and_parse_domain
