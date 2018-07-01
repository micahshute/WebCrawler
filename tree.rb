#tree.rb

require 'set'
require_relative 'parser'


class Tree
    attr_accessor :node_count, :max_level, :nodes_at_level
    attr_reader :parent_node

    def initialize(parent_node)
        @parent_node = TreeNode.new(parent_node, self)
        @nodes_at_level = {1 => [@parent_node]}
        @node_count = 1
        @max_level = 1
    end

    def add_child(child, parent)
        parent.add_child(child)
    end

    def add_children(children, parent)
        parent.add_children(children)
    end

    def bfs(node_data)

    end

    def levels
    end

end


class LinkTree < Tree
    #parse is a funciton which returns the new children of that node
    #to be used for first_time construction
    def bf_traverse_and_construct(seed_name)
        seen = Set.new
        queue = []
        queue << self.parent_node
        seen.add(self.parent_node.data)
        counter = 0
        failed = 0
        children_added = 0
        errors = []
        puts "CONSTRUCTING FILE: #{seed_name}_tree_construct_pages"
        FileUtils.rm_rf("./#{seed_name}_tree_construct_pages")
        Dir.mkdir("#{seed_name}_tree_construct_pages")
        while queue.length > 0
            #Sleep to help prevent overloading a server
            sleep(0.05)
            #Show cli interaction of links in queue and queue length
            puts "\n\n\n"
            puts queue.map{|node| node.data}
            puts "\n\n\n"
            puts "Children added last iteration: #{children_added}"
            url_node = queue.shift
            puts "Current Queue Length #{queue.length}"
            puts "#{counter} page(s) cralwed, #{failed} page(s) failed"
            #open page, write the url name to file, parse all links on page, filter out those already seen, and the remaining to the queue
            begin
                html = open(url_node.data)
                doc = Nokogiri::HTML(html)
                file = File.new("./#{seed_name}_tree_construct_pages/#{seed_name}_page_#{counter}", "a")
                #Can perform additional parsing here to minimize space and make document ready for indexer
                # file_content = doc
                
                counter += 1
                children_data = yield(doc).select{|child| !!seen.add?(child)}
                url_node.add_children_data(children_data)
                queue.concat(url_node.children)
                children_added = children_data.length
                url_node.data = {url_node.data => file}
                to_write = Parser.parse(doc)
                file.write(to_write)
                file.close()
            rescue => error
                errors << error
                url_node.data = {url_node.data => nil}
                failed += 1
            end
        end
        puts("\n\nAttempted to crawl #{counter + failed} pages. #{counter} domain links successfully crawled. Failed to crawl #{failed} links due to the following errors: #{errors}.")
    end

    def bf_traverse_and_parse(parser)
        # -> can implement a method to traverse your and parse cached documents in how you see fit.
        # -> should be done on a tree with linked files to urls
        # -> Done if Parser.parse not used initially
        # -> out of scope for this project
    end
end

class TreeNode 
    attr_accessor :data, :parent, :children, :tree, :level

    def initialize(data, tree, parent = nil, children = [])
        @data = data
        @parent = parent
        @children = children
        @tree = tree
        @tree.node_count += 1 if !!parent
        @level = !!parent ? parent.level + 1 : 1
        @tree.max_level = @level if @level > @tree.max_level if !!parent
        (!!@tree.nodes_at_level[@level] ? @tree.nodes_at_level[@level] << self : @tree.nodes_at_level[@level] = [self]) if !!parent

    end

    def siblings
        !!@parent ? @parent.children : self
    end

    def siblings_exclusive
        self.siblings.reject{|c| c == self}
    end

    def cousins
        if !!self.parent && !!self.parent.parent
            return @parent.parent.children.map{|gen| gen.children}.flatten
        elsif !!self.parent 
            return self.siblings
        end
        self
    end

    def cousins_exclusive
        self.cousins.reject{|c| c == self}
    end

    def add_child_data(child_data)
        child = TreeNode.new(child_data, self.tree, self)
        self.children << child
    end

    def add_child(child)
        self.children << child
    end

    def add_children_data(children_data)
        child_nodes = children_data.map{|data| TreeNode.new(data, self.tree, self)}
        self.children.concat(child_nodes)
    end

    def add_children(children)
        self.children.concat(children)
    end

    def children_data
        self.children.map{|c| c.data}
    end

end
