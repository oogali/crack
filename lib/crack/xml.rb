require 'rexml/parsers/streamparser'
require 'rexml/parsers/baseparser'
require 'rexml/light/node'
require 'rexml/text'
require 'date'
require 'time'
require 'yaml'
require 'bigdecimal'

# This is a slighly modified version of the XMLUtilityNode from
# http://merb.devjavu.com/projects/merb/ticket/95 (has.sox@gmail.com)
# It's mainly just adding vowels, as I ht cd wth n vwls :)
# This represents the hard part of the work, all I did was change the
# underlying parser.
class REXMLUtilityNode #:nodoc:
  attr_accessor :name, :attributes, :children

  def initialize(name, normalized_attributes = {})

    # unnormalize attribute values
    attributes = Hash[* normalized_attributes.map { |key, value|
      [ key, unnormalize_xml_entities(value) ]
    }.flatten]

    @name         = name.tr("-", "_")
    @nil_element  = attributes.delete("nil") == "true"
    @attributes   = undasherize_keys(attributes)
    @children     = []
    @text         = false
  end

  def add_node(node)
    @text = true if node.is_a? String
    @children << node
  end

  def to_hash
    if @text
      t = unnormalize_xml_entities( inner_html )
      if t.is_a?(String)
        class << t
          attr_accessor :attributes
        end
        t.attributes = attributes
      end
      return { name => t }
    else
      #change repeating groups into an array
      groups = @children.inject({}) { |s,e| (s[e.name] ||= []) << e; s }

      out = {}
      groups.each do |k,v|
        if v.size == 1
          out.merge!(v.first)
        else
          out.merge!( k => v.map{|e| e.to_hash[k]})
        end
      end
      out.merge! attributes unless attributes.empty?
      out = out.empty? ? nil : out

      { name => out }
    end
  end

  # Take keys of the form foo-bar and convert them to foo_bar
  def undasherize_keys(params)
    params.keys.each do |key, value|
      params[key.tr("-", "_")] = params.delete(key)
    end
    params
  end

  # Get the inner_html of the REXML node.
  def inner_html
    @children.join
  end

  # Converts the node into a readable HTML node.
  #
  # @return <String> The HTML node in text form.
  def to_html
    "<#{name}#{Crack::Util.to_xml_attributes(attributes)}>#{@nil_element ? '' : inner_html}</#{name}>"
  end

  # @alias #to_html #to_s
  def to_s
    to_html
  end

  private

  def unnormalize_xml_entities value
    REXML::Text.unnormalize(value)
  end
end

module Crack
	class REXMLParser
    def self.parse(xml)
      stack = []
      parser = REXML::Parsers::BaseParser.new(xml)

      while true
        event = parser.pull
        case event[0]
        when :end_document
          break
        when :end_doctype, :start_doctype
          # do nothing
        when :start_element
          stack.push REXMLUtilityNode.new(event[1], event[2])
        when :end_element
          if stack.size > 1
            temp = stack.pop
            stack.last.add_node(temp)
          end
        when :text, :cdata
          stack.last.add_node(event[1]) unless event[1].strip.length == 0 || stack.empty?
        end
      end
      stack.length > 0 ? stack.pop.to_hash : {}
    end
  end

  class XML
    def self.parser
      @@parser ||= REXMLParser
    end

    def self.parser=(parser)
      @@parser = parser
    end

    def self.parse(xml)
      parser.parse(xml)
    end
  end
end
