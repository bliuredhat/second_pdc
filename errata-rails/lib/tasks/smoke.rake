namespace :smoke do 
  desc "Simple smoke test to verify system config"
  task :simple => :environment do
    p "env valid"
  end
end
