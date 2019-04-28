module Import::ExternalParsers
  include Import::ImportConstants

  ### NOTE ON KNOWN SOURCES
  # These lists will stop with the first one it matches, so put more-specific matches
  # towards the front of the list.

  # places for which we have a custom parse_story_from_[source] method
  # for getting information out of the downloaded text
  KNOWN_STORY_PARSERS = %w[deviantart dw lj].freeze

  # places for which we have a custom parse_author_from_[source] method
  # which returns an external_author object including an email address
  KNOWN_AUTHOR_PARSERS = %w[lj].freeze

  # places for which we have a download_story_from_[source]
  # used to customize the downloading process
  KNOWN_STORY_LOCATIONS = %w[lj].freeze

  # places for which we have a download_chaptered_from
  # to get a set of chapters all together
  CHAPTERED_STORY_LOCATIONS = %w[ffnet thearchive_net efiction quotev].freeze

  # regular expressions to match against the URLS
  SOURCE_LJ = %r{((live|dead|insane)journal\.com)|journalfen(\.net|\.com)|dreamwidth\.org}i
  SOURCE_DW = %r{dreamwidth\.org}i
  SOURCE_FFNET = %r{(^|[^A-Za-z0-9-])fanfiction\.net}i
  SOURCE_DEVIANTART = %r{deviantart\.com}i
  SOURCE_THEARCHIVE_NET = %r{the-archive\.net}i
  SOURCE_EFICTION = %r{viewstory\.php}i
  SOURCE_QUOTEV = %r{quotev\.com}i

  #####################################
  # LIVEJOURNAL                       #
  #####################################
  def parse_author_from_lj(location)
    return if location !~ %r{^(?:http:\/\/)?(?<lj_name>[^.]*).(?<site_name>livejournal\.com|dreamwidth\.org|insanejournal\.com|journalfen.net)}
    email = ""
    lj_name = Regexp.last_match[:lj_name]
    site_name = Regexp.last_match[:site_name]
    if lj_name == "community"
      # whups
      post_text = download_text(location)
      doc = Nokogiri.parse(post_text)
      lj_name = doc.xpath("/html/body/div[2]/div/div/div/table/tbody/tr/td[2]/span/a[2]/b").content
    end
    profile_url = "http://#{lj_name}.#{site_name}/profile"
    lj_profile = download_text(profile_url)
    doc = Nokogiri.parse(lj_profile)
    contact = doc.css('div.contact').inner_html
    if contact.present?
      contact.gsub! '<p class="section_body_title">Contact:</p>', ""
      contact.gsub! /<\/?(span|i)>/, ""
      contact.delete! "\n"
      contact.gsub! "<br/>", ""
      if contact =~ /(.*@.*\..*)/
        email = Regexp.last_match[1]
      end
    end
    email = "#{lj_name}@#{site_name}" if email.blank?
    parse_author_common(email, lj_name)
  end

  # canonicalize the url for downloading from lj or clones
  def download_from_lj(location)
    url = location
    url.gsub!(/\#(.*)$/, "") # strip off any anchor information
    url.gsub!(/\?(.*)$/, "") # strip off any existing params at the end
    url.gsub!('_', '-') # convert underscores in usernames to hyphens
    url += "?format=light" # go to light format
    text = download_with_timeout(url)

    if text.match(/adult_check/)
      Timeout::timeout(STORY_DOWNLOAD_TIMEOUT) {
        begin
          agent = Mechanize.new
          url.include?("dreamwidth") ? form = agent.get(url).forms.first : form = agent.get(url).forms.third
          page = agent.submit(form, form.buttons.first) # submits the adult concepts form
          text = page.body.force_encoding(agent.page.encoding)
        rescue
          text = ""
        end
      }
    end
    text
  end

  # Parses a story from livejournal or a livejournal equivalent (eg, dreamwidth, insanejournal)
  # Assumes that we have downloaded the story from one of those equivalents (ie, we've downloaded
  # it in format=light which is a stripped-down plaintext version.)
  #
  def parse_story_from_lj(_story, detect_tags = true)
    work_params = { chapter_attributes: {} }

    # in LJ "light" format, the story contents are in the second div
    # inside the body.
    body = @doc.css("body")
    storytext = body.css("article.b-singlepost-body").inner_html
    storytext = body.inner_html if storytext.empty?

    # cleanup the text
    # storytext.gsub!(/<br\s*\/?>/i, "\n") # replace the breaks with newlines
    storytext = clean_storytext(storytext)

    work_params[:chapter_attributes][:content] = storytext
    work_params[:title] = @doc.css("title").inner_html
    work_params[:title].gsub! /^[^:]+: /, ""
    work_params.merge!(scan_text_for_meta(storytext, detect_tags))

    date = @doc.css("time.b-singlepost-author-date")
    unless date.empty?
      work_params[:revised_at] = convert_revised_at(date.first.inner_text)
    end

    work_params
  end


  #####################################
  # DREAMWIDTH                        #
  #####################################
  def parse_story_from_dw(_story, detect_tags = true)
    work_params = { chapter_attributes: {} }

    body = @doc.css("body")
    content_divs = body.css("div.contents")

    if content_divs[0].present?
      # Get rid of the DW metadata table
      content_divs[0].css("div.currents, ul.entry-management-links, div.header.inner, span.restrictions, h3.entry-title").each(&:remove)
      storytext = content_divs[0].inner_html
    else
      storytext = body.inner_html
    end

    # cleanup the text
    storytext = clean_storytext(storytext)

    work_params[:chapter_attributes][:content] = storytext
    work_params[:title] = @doc.css("title").inner_html
    work_params[:title].gsub! /^[^:]+: /, ""
    work_params.merge!(scan_text_for_meta(storytext, detect_tags))

    font_blocks = @doc.xpath('//font')
    unless font_blocks.empty?
      date = font_blocks.first.inner_text
      work_params[:revised_at] = convert_revised_at(date)
    end

    # get the date
    date = @doc.css("span.date").inner_text
    work_params[:revised_at] = convert_revised_at(date)

    work_params
  end


  #####################################
  # DEVIANTART                        #
  #####################################

  def parse_story_from_deviantart(_story, detect_tags = true)
    work_params = { chapter_attributes: {} }
    storytext = ""
    notes = ""

    body = @doc.css("body")
    title = @doc.css("title").inner_html.gsub /\s*on deviantart$/i, ""

    # Find the image (original size) if it's art
    image_full = body.css("div.dev-view-deviation img.dev-content-full")
    unless image_full[0].nil?
      storytext = "<center><img src=\"#{image_full[0]["src"]}\"></center>"
    end

    # Find the fic text if it's fic (needs the id for disambiguation, the "deviantART loves you" bit in the footer has the same class path)
    text_table = body.css(".grf-indent > div:nth-child(1)")[0]
    unless text_table.nil?
      # Try to remove some metadata (title and author) from the work's text, if possible
      # Try to remove the title: if it exists, and if it's the same as the browser title
      if text_table.css("h1")[0].present? && title && title.match(text_table.css("h1")[0].text)
        text_table.css("h1")[0].remove
      end

      # Try to remove the author: if it exists, and if it follows a certain pattern
      if text_table.css("small")[0].present? && text_table.css("small")[0].inner_html.match(/by ~.*?<a class="u" href=/m)
        text_table.css("small")[0].remove
      end
      storytext = text_table.inner_html
    end

    # cleanup the text
    storytext.gsub!(%r{<br\s*\/?>}i, "\n") # replace the breaks with newlines
    storytext = clean_storytext(storytext)
    work_params[:chapter_attributes][:content] = storytext

    # Find the notes
    content_divs = body.css("div.text-ctrl div.text")
    notes = content_divs[0].inner_html unless content_divs[0].nil?

    # cleanup the notes
    notes.gsub!(%r{<br\s*\/?>}i, "\n") # replace the breaks with newlines
    notes = clean_storytext(notes)
    work_params[:notes] = notes

    work_params.merge!(scan_text_for_meta(notes, detect_tags))
    work_params[:title] = title

    body.css("div.dev-title-container h1 a").each do |node|
      if node["class"] != "u"
        work_params[:title] = node.inner_html
      end
    end

    tags = []
    @doc.css("div.dev-about-cat-cc a.h").each { |node| tags << node.inner_html }
    work_params[:freeform_string] = clean_tags(tags.join(ArchiveConfig.DELIMITER_FOR_OUTPUT))

    details = @doc.css("div.dev-right-bar-content span[title]")
    unless details[0].nil?
      work_params[:revised_at] = convert_revised_at(details[0].inner_text)
    end

    work_params
  end


  #####################################
  # EFICTION VARIANTS                 #
  #####################################

  # this is an efiction archive but it doesn't handle chapters normally
  # best way to handle is to get the full story printable version
  # We have to make it a download-chaptered because otherwise it gets sent to the
  #  generic efiction version since chaptered sources are checked first
  def download_chaptered_from_thearchive_net(location)
    if location.match(/^(.*)\/.*viewstory\.php.*[^p]sid=(\d+)($|&)/i)
      location = "#{$1}/viewstory.php?action=printable&psid=#{$2}"
    end
    text = download_with_timeout(location)
    text.sub!('</style>', '</style></head>') unless text.match('</head>')
    [text]
  end

  # grab all the chapters of a story from an efiction-based site
  def download_chaptered_from_efiction(location)
    chapter_contents = []
    if location.match(/^(?<site>.*)\/.*viewstory\.php.*sid=(?<storyid>\d+)($|&)/i)
      site = Regexp.last_match[:site]
      storyid = Regexp.last_match[:storyid]
      chapnum = 1
      last_body = ""
      Timeout::timeout(STORY_DOWNLOAD_TIMEOUT) do
        loop do
          url = "#{site}/viewstory.php?action=printable&sid=#{storyid}&chapter=#{chapnum}"
          body = download_with_timeout(url)
          # get a section to check that this isn't a duplicate of previous chapter
          body_to_check = body.slice(10, DUPLICATE_CHAPTER_LENGTH)
          if body.nil? || body_to_check == last_body || chapnum > MAX_CHAPTER_COUNT || body.match(/<div class='chaptertitle'> by <\/div>/) || body.match(/Access denied./) || body.match(/Chapter : /)
            break
          end
          # save the value to check for duplicate chapter
          last_body = body_to_check

          # clean up the broken head in many efiction printable sites
          body.sub!('</style>', '</style></head>') unless body.match('</head>')
          chapter_contents << body
          chapnum += 1
        end
      end
    end
    chapter_contents
  end

  def parse_story_from_modified_efiction(story, site = "")
    work_params = { chapter_attributes: {} }
    storytext = @doc.css("div.chapter").inner_html
    storytext = clean_storytext(storytext)
    work_params[:chapter_attributes][:content] = storytext

    work_params[:title] = @doc.css("html body div#pagetitle a").first.inner_text.strip
    work_params[:chapter_attributes][:title] = @doc.css(".chaptertitle").inner_text.gsub(/ by .*$/, '').strip

    # harvest data
    info = @doc.css(".infobox .content").inner_html

    if info.match(/Summary:.*?>(.*?)<br>/m)
      work_params[:summary] = clean_storytext($1)
    end

    infotext = @doc.css(".infobox .content").inner_text

    # Turn categories, genres, warnings into freeform tags
    tags = []
    if infotext.match(/Categories: (.*) Characters:/)
      tags += $1.split(',').map {|c| c.strip}.uniq unless $1 == "None"
    end
    if infotext.match(/Genres: (.*)Warnings/)
      tags += $1.split(',').map {|c| c.strip}.uniq unless $1 == "None"
    end
    if infotext.match(/Warnings: (.*)Challenges/)
      tags += $1.split(',').map {|c| c.strip}.uniq unless $1 == "None"
    end
    work_params[:freeform_string] = clean_tags(tags.join(ArchiveConfig.DELIMITER_FOR_OUTPUT))

    # use last updated date as revised_at date
    if site == "lotrfanfiction" && infotext.match(/Updated: (\d\d)\/(\d\d)\/(\d\d)/)
      # need yy/mm/dd to convert
      work_params[:revised_at] = convert_revised_at("#{$3}/#{$2}/#{$1}")
    elsif site == "twilightarchives" && infotext.match(/Updated: (.*)$/)
      work_params[:revised_at] = convert_revised_at($1)
    end

    # get characters
    if infotext.match(/Characters: (.*)Genres:/)
      work_params[:character_string] = $1.split(',').map {|c| c.strip}.uniq.join(',') unless $1 == "None"
    end

    # save the readcount
    readcount = 0
    if infotext.match(/Read: (\d+)/)
      readcount = $1
    end
    work_params[:notes] = (readcount == 0 ? "" : "<p>This work was imported from another site, where it had been read #{readcount} times.</p>")

    # story notes, chapter notes, end notes
    @doc.css(".notes").each do |note|
      if note.inner_html.match(/Story Notes/)
        work_params[:notes] += note.css('.noteinfo').inner_html
      elsif note.inner_html.match(/(Chapter|Author\'s) Notes/)
        work_params[:chapter_attributes][:notes] = note.css('.noteinfo').inner_html
      elsif note.inner_html.match(/End Notes/)
        work_params[:chapter_attributes][:endnotes] = note.css('.noteinfo').inner_html
      end
    end

    if infotext.match(/Completed: No/)
      work_params[:complete] = false
    else
      work_params[:complete] = true
    end

    work_params
  end


  #####################################
  # BLOCKED EXTERNAL SITES            #
  #####################################

  def download_chaptered_from_ffnet(location)
    raise Import::StoryParser::Error, "Sorry, Fanfiction.net does not allow imports from their site."
  end

  def download_chaptered_from_quotev(_location)
    raise Import::StoryParser::Error, "Sorry, Quotev.com does not allow imports from their site."
  end

end
