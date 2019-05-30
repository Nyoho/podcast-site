class Episode
  attr_reader :path, :title, :description
  attr_accessor :original_audio_file_url, :duration
  
  def initialize(path)
    @path = path
    body
  end

  def no
    path.match(/episodes\/(.+)\.html/)[1]
  end

  def date
    begin
      @date = DateTime.parse(@date) if @date.class == String
    rescue
      STDERR.puts "Parse error date from file: path"
    end
    @date
  end

  def starring
    if @starring.class == String
      @starring = @starring.split(/\s+/)
    end
    @starring
  end

  def body
    @body ||= begin
                ERB.new(File.read(path)).result(binding)
              end
  end

  def audio_file_url
    "/files/#{no}.mp3"
  end
end
