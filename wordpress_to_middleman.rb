# Input: WordPress XML export file.
# Outputs: a series of Markdown files ready to be included in a middleman site

require 'rubygems'
require 'nokogiri'
require 'upmark'
require 'reverse_markdown'
require 'time'
require 'fileutils'

# SETTINGS #
WORDPRESS_XML_FILE_PATH = "#{ENV['PWD']}/wordpress.xml" # THE LOCATION OF THE EXPORTED WORDPRESS ARCHIVE #
OUTPUT_PATH = "#{ENV['PWD']}/export/_posts/" # THE LOCATION OF THE SAVED POSTS #
ORIGINAL_DOMAIN = 'http://tech.feedforce.jp' #  THE DOMAIN OF THE WEBSITE #
SEPARATE_CATEGORIES_FROM_TAGS = false
CONVERT_FROM_HTML = true

class Parser

  def self.make_output_path
    unless File.directory?(OUTPUT_PATH)
      FileUtils.mkdir_p(OUTPUT_PATH)
      puts 'Saving all files in' + OUTPUT_PATH.to_s
    end
  end

  def self.xml_to_hash
    # xml = Nokogiri::HTML(open(WORDPRESS_XML_FILE_PATH.gsub("CDATA", "")))
    f = File.open(WORDPRESS_XML_FILE_PATH)
    xml = Nokogiri::XML(f)
    posts = xml.css('item')

    posts.each do |post|

      # Parsing Post Frontmatter
      # ------------------------------------
      title = post.xpath('wp:post_name').inner_text
      title_ja = post.css('title').text
      title.gsub!(':', '-')
      post_date = post.xpath('wp:post_date').first.inner_text
      post_date = DateTime.parse(post_date).strftime('%Y-%m-%d %H:%M JST')

      created_at = Date.parse(post_date).to_s
      author = post.at_xpath('.//dc:creator').inner_text

      tags = ''
      categories = ''
      category_xml = post.xpath('category')

      if SEPARATE_CATEGORIES_FROM_TAGS
        category_xml.each do |category|
          if category.css('@domain').to_s == 'category'
            categories += category.css('@nicename').text + ', '
          else
            tags += category.css('@nicename').text + ', '
          end
        end
      else
        category_xml.each do |category|
          tags += category.css('@nicename').text + ', '
        end
      end

      # Parsing Post Content
      # ------------------------------------
      # content = post.at_xpath(".//content:encoded").to_s
      content = post.at_xpath('.//content:encoded').inner_text

      # Cleaning up the HTML output of content
      # content.gsub!("<encoded>", " ")
      # content.gsub!("</encoded>", " ")
      # content.gsub!("&gt;", " ")
      # content.gsub("<![CDATA[", " ")
      # content.gsub!("]];", " ")
      # content.gsub!("]]>;", " ")

      # Converting HTML output to Markdown

      # do a crude test for html tags
      if CONVERT_FROM_HTML && /</ =~ content && />/ =~ content
        content.gsub!(/(\r?\n\r?\n)/, 'XXXXXXXXXX') # preserve double newline as token
        content.gsub!(/\n(<.+>)/, "<br><br>\\1") # add newline before html tags
        md_content = ReverseMarkdown.convert(content, unknown_tags: :pass_through, github_flavored: true)
        content = md_content
        content.gsub!(/(XXXXXXXXXX)+/, "\n\n") # remove token and replace with double newline
      end

      content.gsub! /\n\s*\n/, "\n\n" # collapse newlines

      if !(created_at.nil? || title.nil? || post_date.nil? || content.nil?)
        output_filename = OUTPUT_PATH + created_at + '-' + sanitize_filename(title) + '.md'
        puts output_filename

        file_content = '---' + "\n"
        file_content += 'title: ' + title_ja + "\n"
        file_content += 'date: ' + post_date + "\n"
        file_content += 'authors: ' + author + "\n"
        file_content += 'tags: ' + tags + "\n"
        if SEPARATE_CATEGORIES_FROM_TAGS
          file_content += 'categories: ' + categories + '\n' unless categories.empty?
        end
        file_content += '---' + "\n"
        file_content += content

        # Saving File
        # ------------------------------------
        File.open(output_filename, 'w') do |f|
          f.write(file_content)
        end
      end
    end
  end

  def self.sanitize_filename(filename)
    filename.gsub(/[^\w\s_-]+/, '')
        .gsub(/(^|\b\s)\s+($|\s?\b)/, '\\1\\2')
        .gsub(/\s+/, '_')
        .downcase
  end

end

Parser.make_output_path
Parser.xml_to_hash


