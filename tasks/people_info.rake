
desc "Update people information"
task people_info: :environment do
  PodcastSite::UpdateTask.new.update
end
