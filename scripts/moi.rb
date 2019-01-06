#!/usr/bin/env ruby
# encoding: utf-8

require 'rexml/document'
require 'optparse'
require 'open-uri'
require 'digest'
require 'json'
require 'active_support/core_ext/hash/conversions'

$appkey = "******"
$key = "******"

class Moi
  def initialize(options = {})
    @options = options
    @word = options[:word]
  end
  
  def translate
    if @word && !@word.empty?
      toJp = "ja"
      toEn = "EN"

      parse generateXml toEn
      jParse generateXml toJp
    end
  end

  def generateXml(toLang)
     return JSON.parse(http(toLang).string).to_xml(:root => :my_root)
  end

  def parse(src)
    xml = REXML::Document.new(src)

    parse_phonetic_symbol xml
    
    __ "英语翻译: #{@word}", "="
    parse_dict_trans      xml
  end
  
  def jParse(src)
    xml = REXML::Document.new(src)

    __ "日语翻译: #{@word}", "="
    parse_japanses_trans      xml
  end

  protected
    # 音标
    def parse_phonetic_symbol(xml)
      xml.each_node('//basic/phonetic') do |node|
        if node.text
          indent
          print @word
          puts " [#{node.text}]".cyan
        end
      end
    end

    # 词典
    def parse_dict_trans(xml)
      if xml.first_node('//explains/explain') 
        xml.each_node('//explains/explain') do |node|
          indent
          puts node.text.green
        end
      else 
        xml.each_node('//translation/translation') do |node|
          indent
          puts node.text.green
        end
      end
    end

    # 日语
    def parse_japanses_trans(xml)
      xml.each_node('//translation/translation') do |node|
        indent
        puts node.text.green
      end
    end

    def http( to )
      q = @word
      salt = NewPass.new().create
      sign = Digest::MD5.hexdigest(($appkey + q + salt + $key).encode('utf-8')).upcase

      url = "http://openapi.youdao.com/api?q=#{q}&from=auto&salt=#{salt}&appKey=#{$appkey}&sign=#{sign}"
        
      begin
        uri = URI.parse(url.force_encoding('UTF-8') + "&to=#{to}")
      rescue URI::InvalidURIError
        uri = URI.parse(URI.escape(url.force_encoding('UTF-8')) + "&to=#{to}")
      end

      open(uri) do |src|
        return src
      end
    end

  private
    def __(t, pad='-', len=30 )
      puts " #{t} ".center(len, pad)
    end

    def indent(idt=2)
      print " " * idt
    end

end

class NewPass 
  def initialize(len = 15)
    @len = len
  end
  
  def create
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    newpass = ""
    1.upto(@len) { |i| newpass << chars[rand(chars.size-1)] }
    return newpass
  end
end

module REXML
  class Element
    def each_node(path, &block); XPath.each(self, path, &block); end
    def first_node(path); XPath.first(self, path); end
  end
end

class String
  COLORS = %w(black red green yellow blue magenta cyan white)
  COLORS.each_with_index do |color, idx|
    define_method color do
      "\e[3#{idx}m" << self.to_s << "\e[0m"
    end

    define_method "#{color}_bg" do
      "\e[4#{idx}m" << self.to_s << "\e[0m"
    end
  end
end


class Moi::CLI
  def initialize
    options = {accent: 1}
    parser = OptionParser.new do |o|
      o.banner = "Usage: moi <word> [options]"

    end

    options[:word] = parser.parse(ARGV).join(' ')
    Moi.new(options).translate
  end
end

## script entrace
Moi::CLI.new if __FILE__ == $0