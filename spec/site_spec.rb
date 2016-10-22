require File.expand_path("../../config/boot.rb", __FILE__)
require 'sitespec/rspec'
require './app/app'
# require 'pry'

Sitespec.configuration.build_path = '_site'

describe 'Sitespec' do
  let(:app) do
    PodcastSite::App
  end

  %w[
    / /podcast.rss
  ].each do |path|
    describe "GET #{path}", :sitespec do
      it "returns 200" do
        expect(get(path).status).to eq 200
      end
    end
  end

  Dir.glob('episodes/*.html').each do |filepath|
    describe "GET #{filepath}", :sitespec do
      it "generate event page #{filepath}" do
        episode_no = filepath.match(/episodes\/(.+)\.html/)[1]
        path = "/#{episode_no}/"
        expect(get(path).status).to eq 200
      end
    end
  end
end
