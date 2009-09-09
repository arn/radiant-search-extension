class SearchPage < Page
  description "Provides tags and behavior to support searching Radiant.  Based on Oliver Baltzer's search_behavior."
  attr_accessor :query_result, :query
  #### Tags ####
   
  desc %{    Renders the passed query.}
  tag 'search:query' do |tag|
    CGI.escapeHTML(query)
  end
  
  desc %{   Renders the contained block when query is blank.}
  tag 'search:initial' do |tag|
    if query.empty?
      tag.expand
    end
  end
 
  desc %{   Renders the contained block if no results were returned.}
  tag 'search:empty' do |tag|
    if query_result.blank? && !query.empty?
      tag.expand
    end
  end
  
  tag 'search:results' do |tag|
    returning String.new do |content|
      query_result.each do |page|
        content << "<p><a href='#{page.url}'>#{page.title}</a><br />"
        content << helper.truncate(helper.strip_tags(page.parts.first.content).gsub(/\s+/," "), 100)
        content << "</p>"
      end
    end
  end

  desc %{    Quantity of search results fetched.}
  tag 'search:results:quantity' do |tag|
    query_result.blank? ? 0 : query_result.size
  end

  desc %{    <r:truncate_and_strip [length="100"] />
    Truncates and strips all HTML tags from the content of the contained block.  
    Useful for displaying a snippet of a found page.  The optional `length' attribute
    specifies how many characters to truncate to.}
  tag 'truncate_and_strip' do |tag|
    tag.attr['length'] ||= 100
    length = tag.attr['length'].to_i
    helper.truncate(helper.strip_tags(tag.expand).gsub(/\s+/," "), length)
  end
  
  desc %{    <r:search:highlight [length="100"] />
    Highlights the search keywords from the content of the contained block.
    Strips all HTML tags and truncates the relevant part.      
    Useful for displaying a snippet of a found page.  The optional `length' attribute
    specifies how many characters to truncate to.}
  tag 'highlight' do |tag|    
    length = (tag.attr['length'] ||= 100).to_i
    content = helper.strip_tags(tag.expand).gsub(/\s+/," ")
    match  = content.match(query.split(' ').first)
    if match
      start = match.begin(0)
      begining = (start - length/2)
      begining = 0 if begining < 0
      chars = content.chars
      relevant_content = chars.length > length ? (chars[(begining)...(begining + length)]).to_s + "..." : content
      helper.highlight(relevant_content, query.split)      
    else
      helper.truncate(content, length)
    end    
  end  
  
  #### "Behavior" methods ####
  def cache?
    false
  end
  
  def render
    @query_result = []
    @query = ""
    q = @request.parameters[:q]

    unless (@query = q.to_s.strip).blank?
      @query_result = Page.find_by_title(q).find_by_status(100) + Page.find_by_content(q).find_by_status(100)
    end
    lazy_initialize_parser_and_context
    if layout
      parse_object(layout)
    else
      render_page_part(:body)
    end
  end
  
  def helper
    @helper ||= ActionView::Base.new
  end
  
end

class Page
  
  named_scope :find_by_status, lambda { |input| {:conditions => ["status_id = ?", input]}}
  named_scope :find_by_content, lambda { |input| {
    :include => :parts,
    :conditions => ["MATCH (page_parts.content) AGAINST ('#{input.gsub(/(\S+)/, '+\1*')}' IN BOOLEAN MODE)"],
    :order => ["MATCH (page_parts.content) AGAINST ('#{input}') DESC"]
    }
  }
  named_scope :find_by_title, lambda { |input| {
    :conditions => ["MATCH (title) AGAINST ('#{input.gsub(/(\S+)/, '+\1*')}' IN BOOLEAN MODE)"],
    :order => ["MATCH (title) AGAINST ('#{input}') DESC"]
    }
  }
  
  #### Tags ####
  desc %{    The namespace for all search tags.}
  tag 'search' do |tag|
    tag.expand
  end

  desc %{    <r:search:form [label=""] [url="search"] [submit="Search"] />
    Renders a search form, with the optional label, submit text and url.}
  tag 'search:form' do |tag|
    label = tag.attr['label'].nil? ? "" : "<label for=\"q\">#{tag.attr['label']}</label> "
    submit = "<input value=\"#{tag.attr['submit'] || "Search"}\" type=\"submit\" />"
    url = tag.attr['url'].nil? ? self.url.chop : tag.attr['url']
    @query ||= ""    
    content = %{<form action="#{url}" method="get" id="search_form"><p>#{label}<input type="text" id="q" name="q" value="#{@query}" size="15" alt=\"search\"/> #{submit}</p></form>}
    content << "\n"
  end

end