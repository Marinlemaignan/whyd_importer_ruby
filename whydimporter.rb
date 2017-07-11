
require 'pry'

# require './discogs/lib/discogs' # sooon
# require 'httparty'
require 'uri'
require 'digest'

### !!! i know i'm a dirty unfinished script..

class WhydImporter
  attr_reader :cookie


  def initialize
    @count = 0
    session ||= {}
  end

  def call
    md5 = Digest::MD5.new.update("yourpassword")
    uri = URI('https://openwhyd.org/login')
    parameters = {
      action: "login",
      ajax: 1,
      email: "youremail@gmail.com",
      md5: md5
    }
    response = HTTParty.get(uri, query: parameters)
    @cookie = response.headers['set-cookie']

    import_from_facebook_data
  end

  def import_from_facebook_data
    # last :: 22/06/2017
    date = Date.parse('22/06/2017')
    # required data is as follow
    # created_time|type|message|link|name|description
    csv = CSV.foreach('your_structured_data.csv', headers: :first_row, col_sep: "|")
      .select { |row|
        row['created_time'] && \
        Date.parse(row['created_time']) >= date && \
        Date.parse(row['created_time']) < Date.today
      }.reverse

    csv.each_with_index do |row, index|
        parsed_url = if row['type'] == 'comment'
          row['message']
        else
          row['link']
        end

        post_track(parsed_url, row['name'], row['description'])
    end
    puts "DONE -> TOTAL :: #{@count}"
  end

  def build_track(url)
    TrackFinder.new(url).get_eid
  end

  def post_track(url, name, description)
    uri = URI('https://openwhyd.org/api/post')
    # u = @discogs.search("Necrovore")
    if eid = build_track(url)
      puts "Insert #{eid}"
      @count += 1
      parameters = {
        action: "insert",
        eId: eid.join(""),
        name: name,
        text: description,
        img: "http://img.youtube.com/vi/#{eid.last}/hqdefault.jpg", # yess this is crappy it only supports ytb thumbnails..
        src: {
          id: url,
          name: name
        },
        pl: {
          id: 1
        }
      }

      response = HTTParty.get(
        uri,
        query: parameters,
        headers: {
          'Cookie' => @cookie
      })
      puts ".... sleeps 1/2s"
      sleep 0.2
      puts "next line"
    end
  end
end



class TrackFinder
  attr_reader :url

  def initialize(url)
    @url = url
  end

  def get_eid
    audiofile   ||
    bandcamp    ||
    dailymotion ||
    deezer      ||
    jamendo     ||
    soundcloud  ||
    spotify     ||
    vimeo       ||
    youtube
  end

  def audiofile
    # # url = (url || "").split("#").pop();
    # # if (!url)
    # #   return null;
    # # var ext = url.split("?")[0].split(".").pop().toLowerCase();
    # # return (ext == "mp3" || ext == "ogg") ? url.replace(/^\/fi\//, "") : null;
    # JS FROM PLAYEMJS

    # soundcloud_regex = [
    #   /(soundcloud\.com)(\/[a-zA-Z0-9_\-\/]+)/,
    #   /snd\.sc\/([a-zA-Z0-9_\-\/]+)/
    # ]
    # match_format?(soundcloud_regex)

    false
  end

  def bandcamp
    bandcamp_regex = [
      /([a-zA-Z0-9_\-]+).bandcamp\.com\/track\/([a-zA-Z0-9_\-]+)/,
      /\/bc\/([a-zA-Z0-9_\-]+)\/([a-zA-Z0-9_\-]+)/
    ]
    match_format?(bandcamp_regex, "/bc/")
  end

  def dailymotion
    dailymotion_regex = [
      /(dailymotion.com(?:\/embed)?\/video\/|\/dm\/)([\w-]+)/
    ]
    match_format?(dailymotion_regex, "/dm/")
  end

  def deezer
    deezer_regex = [
      /(deezer\.com\/track|\/dz)\/(\d+)/
    ]
    match_format?(deezer_regex, "/dz/")
  end

  def jamendo
    jamendo_regex = [
      /jamendo.com\/.*track\/(\d+)/,
      /\/ja\/(\d+)/
    ]
    match_format?(jamendo_regex, "/ja/")
  end

  def soundcloud
    soundcloud_regex = [
      /(soundcloud\.com)(\/[a-zA-Z0-9_\-\/]+)/,
      /snd\.sc\/([a-zA-Z0-9_\-\/]+)/
    ]
    match_format?(soundcloud_regex, "/sc") # regex sucks so ...
  end

  def spotify
    spotify_regex = [
      /spotify.com\/track\/(\w+)/
    ]
    match_format?(spotify_regex, "/sp/")
  end

  def vimeo
    vimeo_regex = [
      /(vimeo\.com\/(clip\:|video\/)?|\/vi\/)(\d+)/
    ]
    match_format?(vimeo_regex, "/vi/")
  end

  def youtube
    yt_regex = [
      (/(youtube\.com\/(v\/|embed\/|(?:.*)?[\?\&]v=)|youtu\.be\/)([a-zA-Z0-9_\-]+)/) ,
      (/^\/yt\/([a-zA-Z0-9_\-]+)/) ,
      (/youtube\.com\/attribution_link\?.*v\%3D([^ \%]+)/),
      (/youtube.googleapis.com\/v\/([a-zA-Z0-9_\-]+)/)
    ]
    match_format?(yt_regex, "/yt/")
  end

  def match_format?(regex, type=nil)
    return false unless type == "/sc" || type == "/vi/" || type == "/bc/" || type == "/yt/"
    if regex.any? { |x| x.match(url) }
      string = url.split("?").last
      ids = regex.map { |x| url.scan(x) }.flatten
      id = ids.last
      return [type, id]
    else
      false
    end
  end
end

WhydImporter.new.call
