namespace :debug do
  namespace :orgchart_xmlrpc do

    desc "lookup a user in orgchart"
    task :user_lookup => :environment do
      pp XMLRPC::OrgChartClient.new(:debug=>true, :verbose=>false).getUser('name'=>ENV['USER'])
    end
  end

end
