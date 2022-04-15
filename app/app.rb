require 'dotenv'
require 'open-uri'
require 'twitter'
require 'rss'
require 'mp3info'
require 'sassc'
require 'json'

# monkey patch
# https://teratail.com/questions/107861
class RSS::Rss::Channel::Item
  def description_element need_convert, indent
    markup = "#{indent}<description>"
    markup << "<![CDATA[#{@description}]]>"
    markup << '</description>'
    markup
  end
end

module PodcastSite
  class App < Padrino::Application
    # register SassInitializer
    register Padrino::Mailer
    register Padrino::Helpers
    enable :sessions
    Encoding.default_internal = nil

    def initialize
      super
      Dotenv.load
      setup_twitter
      @config = YAML.load_file('config.yml')
      @people = YAML.load_file('people.yml')
      @ogimage_url = @config['url'] + '/images/ogimage.jpg'
      @rss_feed = rss_feed
    end

    def setup_twitter
      @twitter = Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
        config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
        config.access_token        = ENV['TWITTER_OAUTH_TOKEN']
        config.access_token_secret = ENV['TWITTER_OAUTH_TOKEN_SECRET']
      end
    end

    get '/stylesheets/main.css' do
      content_type :css
      sass_string = File.read(Padrino.root('app/stylesheets') + '/main.sass')
      SassC::Engine.new(sass_string,
                        style: :compressed,
                        syntax: 'sass',
                        load_paths: [Padrino.root('app/stylesheets')]
                       ).render
    end

    get '/podcast.rss' do
      content_type 'application/rss+xml'
      @rss_feed
    end

    get "/" do
      @title = @config['title']
      @description = @config['description']
      slim :top, locals: { episodes: sorted_episodes }
    end

    get :about, :map => '/about' do
      render :slim, "p About"
    end

    get '/return-setting.conf' do
      content_type 'plain/text'
      episodes_table.values.map {|e|
        <<"EOS"
location #{e.audio_file_url} {
    return 307 #{e.original_audio_file_url};
}
EOS
      }.join
    end

    get "/:no" do |no|
      @title = episodes_table[no].title + ' - ' + @config['title']
      @updated_time = episodes_table[no].date
      @description = episodes_table[no].description
      slim :episode, locals: {
        episode: episodes_table[no]
      }
    end

    def episodes_table
      unless @episodes
        @episodes = {}

        Dir.glob('episodes/*.html').map do |filepath|
          episode = Episode.new(filepath)
          @episodes[episode.no] = episode
        end
      end
      @episodes
    end

    def sorted_episodes
      episodes_table.values.sort {|a,b| b.date <=> a.date }
    end
    
    def rss_feed
      url = @config['use_sound_cloud'] || 'app/views/podcast-template.rss'
      rss = RSS::Parser.parse(url)
      rss.channel.title = @config['title']
      rss.channel.itunes_author = @config['author']
      rss.channel.description = @config['description']
      rss.channel.language = @config['language']
      rss.channel.webMaster = @config['email']

      rss.channel.link = @config['url']
      rss.channel.image.url = rss.channel.itunes_image.href = @config['url'] + '/' + @config['artwork_image_path']
      rss.channel.itunes_owner.itunes_email = @config['email']

      if @config['use_sound_cloud']
        rss.items.select!{|i| episodes_table.has_key?(i.title)}
        rss.items.each do |item|
          episode = episodes_table[item.title]
          item.title = episode.title
          item.link = %Q(#{@config['url']}/#{episode.no}/)
          item.itunes_author = @config['author']
          item.pubDate = episode.date.strftime('%a, %e %b %Y %H:%M:%S %z')
          item.itunes_subtitle = episode.description
          item.description = %Q(#{episode.body}\n<p>この説明は <a href="#{item.link}">#{item.link}</a> でも見られます。</p>\n<p>#{episode.description}</p>\n<p>⌨️📱是非このエピソードの感想を<a href=\"https://twitter.com/intent/tweet?text=%23#{@config['hashtag']}%20ep#{episode.no}%20#{item.link}%20\">Twitterでつぶやいてください</a> (このlinkならハッシュタグ ##{@config['hashtag']} が自動でつきます)!</p>)
          item.itunes_summary = nil
          episode.original_audio_file_url =  item.enclosure.url
          item.enclosure.url = @config['url'] + episode.audio_file_url
          episode.duration = item.itunes_duration
          item.guid.isPermaLink = true
          item.guid.content = item.link
        end
      else
        rss.channel.itunes_owner.itunes_name = @config['author']
        rss.channel.itunes_subtitle = @config['description']
        rss.channel.image.title = @config['title']
        rss.channel.image.link = @config['url']

        item_template = rss.items.pop
        sorted_episodes.each do |episode|
          item = Marshal.load(Marshal.dump(item_template))
          item.title = episode.title
          item.link = %Q(#{@config['url']}/#{episode.no}/)
          item.itunes_author = @config['author']
          item.pubDate = episode.date.strftime('%a, %e %b %Y %H:%M:%S %z')
          item.itunes_subtitle = episode.description
          item.description = %Q(<p>#{episode.description}</p>\n#{episode.body}\n<p>この説明は <a href="#{item.link}">#{item.link}</a> でも見られます。</p>\n<p>⌨️📱是非このエピソードの感想を<a href=\"https://twitter.com/intent/tweet?text=%23#{@config['hashtag']}%20ep#{episode.no}%20#{item.link}%20\">Twitterでつぶやいてください</a> (このlinkならハッシュタグ ##{@config['hashtag']} が自動でつきます)!</p>)
          item.itunes_summary = nil
          item.enclosure.url = @config['url'] + episode.audio_file_url
          episode.original_audio_file_url = item.enclosure.url
          item.enclosure.length = File.size('./public' + episode.audio_file_url)
          # item.itunes_duration is RSS::ITunesItemModel::ITunesDuration
          item.itunes_duration.value = Time.at(Mp3Info.open('./public' + episode.audio_file_url).length).utc.strftime("%H:%M:%S")
          episode.duration = item.itunes_duration
          item.guid.isPermaLink = true
          item.guid.content = item.link
          rss.items << item
        end
      end
      rss.to_s
    end

    ##
    # Caching support.
    #
    # register Padrino::Cache
    # enable :caching
    #
    # You can customize caching store engines:
    #
    # set :cache, Padrino::Cache.new(:LRUHash) # Keeps cached values in memory
    # set :cache, Padrino::Cache.new(:Memcached) # Uses default server at localhost
    # set :cache, Padrino::Cache.new(:Memcached, :server => '127.0.0.1:11211', :exception_retry_limit => 1)
    # set :cache, Padrino::Cache.new(:Memcached, :backend => memcached_or_dalli_instance)
    # set :cache, Padrino::Cache.new(:Redis) # Uses default server at localhost
    # set :cache, Padrino::Cache.new(:Redis, :host => '127.0.0.1', :port => 6379, :db => 0)
    # set :cache, Padrino::Cache.new(:Redis, :backend => redis_instance)
    # set :cache, Padrino::Cache.new(:Mongo) # Uses default server at localhost
    # set :cache, Padrino::Cache.new(:Mongo, :backend => mongo_client_instance)
    # set :cache, Padrino::Cache.new(:File, :dir => Padrino.root('tmp', app_name.to_s, 'cache')) # default choice
    #

    ##
    # Application configuration options.
    #
    # set :raise_errors, true       # Raise exceptions (will stop application) (default for test)
    # set :dump_errors, true        # Exception backtraces are written to STDERR (default for production/development)
    # set :show_exceptions, true    # Shows a stack trace in browser (default for development)
    # set :logging, true            # Logging in STDOUT for development and file for production (default only for development)
    # set :public_folder, 'foo/bar' # Location for static assets (default root/public)
    # set :reload, false            # Reload application files (default in development)
    # set :default_builder, 'foo'   # Set a custom form builder (default 'StandardFormBuilder')
    # set :locale_path, 'bar'       # Set path for I18n translations (default your_apps_root_path/locale)
    # disable :sessions             # Disabled sessions by default (enable if needed)
    # disable :flash                # Disables sinatra-flash (enabled by default if Sinatra::Flash is defined)
    # layout  :my_layout            # Layout can be in views/layouts/foo.ext or views/foo.ext (default :application)
    #

    ##
    # You can configure for a specified environment like:
    #
    #   configure :development do
    #     set :foo, :bar
    #     disable :asset_stamp # no asset timestamping for dev
    #   end
    #

    ##
    # You can manage errors like:
    #
    #   error 404 do
    #     render 'errors/404'
    #   end
    #
    #   error 500 do
    #     render 'errors/500'
    #   end
    #
  end

  class UpdateTask
    def initialize
      super
      Dotenv.load
      setup_twitter
      @config = YAML.load_file('config.yml')
    end

    def setup_twitter
      @twitter = Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
        config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
        config.access_token        = ENV['TWITTER_OAUTH_TOKEN']
        config.access_token_secret = ENV['TWITTER_OAUTH_TOKEN_SECRET']
      end
    end

    def update
      info = @twitter.users @config['people'].map { |k,v| v['twitter'] }
      hash = @config['people'].map do |k,v|
        identifier = k
        nickname = v['name']
        twitter_screen_name = v['twitter']
        github_name = v['github']
        user = info.find {|u| u.screen_name == twitter_screen_name }
        name = user ? user.name : nickname
        github_avatar_url = if user.nil? and github_name then
                              json = URI.open("https://api.github.com/users/#{github_name}").read
                              JSON.parse(json)['avatar_url']
                            end
        image_url = if user
                      user.profile_image_url_https.to_s.gsub(/_normal\./,'.')
                    elsif github_avatar_url
                      github_avatar_url
                    else
                      '/images/someone.png'
                    end
        description = user ? user.description : ''

        v['display_name'] = name
        v['image_url'] = image_url
        v['description'] = description
        [k,v]
      end.to_h
      File.open('people.yml', 'w') {|f| f.write hash.to_yaml }
    end
  end
end

