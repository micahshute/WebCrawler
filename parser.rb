#parser.rb

require 'nokogiri'
require 'open-uri'

class Parser

    #not optimized for machine indexing, more for viewing
    def self.parse(doc, css_types=["h1", "h2", "h3", "ul", "li", "p", "a"])
        output = ''
        css_types.each do |type|
            output += "\n\n#{type}\n\n"
            if type == "a"
                output +=  doc.css(type).map{|a| !!a['href'] ? a['href'] + " => " + a.text.strip + "\n" : ''}.join(" ")
            else
                output += doc.css(type).map{|content|content.text.strip}.join(" ")
            end
            output += "\n\n\n\n----------------------------------------\n\n"
        end
        output
    end

    #dummy method to show implementation place of parser
    def self.untouched(doc)
        doc
    end

    #add methods as necessary for different parsing requirements

end