namespace :one_time_scripts do

  desc "load historical data into text only cpe field"
  task :load_historical_text_only_cpe_data => :environment do

    historical_text_only_cpe_data = {

#
# Copy/paste from https://bugzilla.redhat.com/show_bug.cgi?id=910435#c0
#
"RHSA-2010:0965" => "cpe:/a:redhat:jboss_enterprise_application_platform:4.3/jboss-remoting",
"RHSA-2010:0963" => "cpe:/a:redhat:jboss_enterprise_application_platform:5.1/jboss-remoting",
"RHSA-2010:0962" => "cpe:/a:redhat:jboss_enterprise_web_platform:5.1/jboss-remoting",
"RHSA-2010:0940" => "cpe:/a:redhat:jboss_soa_platform:4.2/jboss-drools,cpe:/a:redhat:jboss_soa_platform:4.3/jboss-drools",
"RHSA-2010:0939" => "cpe:/a:redhat:jboss_enterprise_application_platform:4.3",
"RHSA-2011:0212" => "cpe:/a:redhat:jboss_enterprise_application_platform:4.2,cpe:/a:redhat:jboss_enterprise_application_platform:4.3,cpe:/a:redhat:jboss_enterprise_application_platform:5.1",
"RHSA-2011:0213" => "cpe:/a:redhat:jboss_enterprise_web_platform:5.1",
"RHSA-2011:0333" => "cpe:/a:redhat:jboss_soa_platform:4.3/jbossweb,cpe:/a:redhat:jboss_soa_platform:5.0/jbossweb",
"RHSA-2011:0334" => "cpe:/a:redhat:jboss_enterprise_portal_platform:4.3/jbossweb,cpe:/a:redhat:jboss_enterprise_portal_platform:5/jbossweb",
"RHSA-2011:0350" => "cpe:/a:redhat:jboss_enterprise_web_server:1.0/tomcat",
"RHSA-2011:0462" => "cpe:/a:redhat:jboss_enterprise_application_platform:4.3/jboss_seam,cpe:/a:redhat:jboss_enterprise_application_platform:5.1/jboss-seam",
"RHSA-2011:0463" => "cpe:/a:redhat:jboss_soa_platform:4.3/jboss-seam,cpe:/a:redhat:jboss_soa_platform:5.0/jboss-seam",
"RHSA-2011:0952" => "cpe:/a:redhat:jboss_soa_platform:4.3/jboss-seam,cpe:/a:redhat:jboss_soa_platform:5.1/jboss-seam",
"RHSA-2011:0951" => "cpe:/a:redhat:jboss_enterprise_application_platform:4.3/jboss-seam",
"RHSA-2011:0949" => "cpe:/a:redhat:jboss_enterprise_application_platform:5.1/jboss-seam",
#"RHSA-2011:0945" => "cpe:/a:redhat:jboss_enterprise_web_platform:5.1",
"RHSA-2011:0896" => "cpe:/a:redhat:jboss_enterprise_web_server:1.0",
"RHSA-2011:1148" => "cpe:/a:redhat:jboss_communications_platform:5.1/jboss-seam",
"RHSA-2011:1251" => "cpe:/a:redhat:jboss_enterprise_portal_platform:5/jboss-seam",
"RHSA-2011:1313" => "cpe:/a:redhat:jboss_enterprise_brms_platform:5.1",
"RHSA-2011:1312" => "cpe:/a:redhat:jboss_enterprise_application_platform:4.3/jbossws-common",
"RHSA-2011:1311" => "cpe:/a:redhat:jboss_enterprise_portal_platform:5/jbossws-common",
"RHSA-2011:1310" => "cpe:/a:redhat:jboss_enterprise_application_platform:4.2",
"RHSA-2011:1308" => "cpe:/a:redhat:jboss_communications_platform:5.1,cpe:/a:redhat:jboss_communications_platform:1.2",
"RHSA-2011:1307" => "cpe:/a:redhat:jboss_enterprise_application_platform:4.3",
"RHSA-2011:1305" => "cpe:/a:redhat:jboss_soa_platform:4.2,cpe:/a:redhat:jboss_soa_platform:4.3,cpe:/a:redhat:jboss_soa_platform:5.1",
"RHSA-2011:1304" => "cpe:/a:redhat:jboss_enterprise_web_platform:5.1/jbossws-common",
"RHSA-2011:1302" => "cpe:/a:redhat:jboss_enterprise_application_platform:5.1/jbossws-common",
"RHSA-2011:1334" => "cpe:/a:redhat:jboss_soa_platform:5.1",
"RHSA-2011:1330" => "cpe:/a:redhat:jboss_enterprise_web_server:1.0/httpd",
"RHSA-2011:1806" => "cpe:/a:redhat:jboss_enterprise_web_platform:5.1",
"RHSA-2011:1805" => "cpe:/a:redhat:jboss_enterprise_application_platform:5.1",
"RHSA-2011:1456" => "cpe:/a:redhat:jboss_soa_platform:5.1",
"RHSA-2011:1822" => "cpe:/a:redhat:jboss_enterprise_portal_platform:5",
"RHSA-2012:0040" => "cpe:/a:redhat:jboss_enterprise_web_platform:5.1",
"RHSA-2012:0038" => "cpe:/a:redhat:jboss_enterprise_application_platform:5.1",
"RHSA-2012:0036" => "cpe:/a:redhat:jboss_enterprise_web_server:1.0",
"RHSA-2012:0041" => "cpe:/a:redhat:jboss_enterprise_application_platform:4.3",
"RHSA-2012:0075" => "cpe:/a:redhat:jboss_enterprise_application_platform:5.1",
"RHSA-2012:0077" => "cpe:/a:redhat:jboss_enterprise_web_platform:5.1",
"RHSA-2012:0078" => "cpe:/a:redhat:jboss_communications_platform:5.1",
"RHSA-2012:0089" => "cpe:/a:redhat:jboss_operations_network:2.4",
"RHSA-2012:0091" => "cpe:/a:redhat:jboss_enterprise_portal_platform:4.3/",
"RHSA-2012:0108" => "cpe:/a:redhat:jboss_enterprise_application_platform:5.1",
"RHSA-2012:0325" => "cpe:/a:redhat:jboss_enterprise_brms_platform:5.1,cpe:/a:redhat:jboss_enterprise_portal_platform:5.2,cpe:/a:redhat:jboss_soa_platform:5.2",
"RHSA-2012:0345" => "cpe:/a:redhat:jboss_enterprise_portal_platform:4.3",
"RHSA-2012:0378" => "cpe:/a:redhat:jboss_soa_platform:5.2",
"RHSA-2012:0396" => "cpe:/a:redhat:jboss_operations_network:2.4",
"RHSA-2012:0406" => "cpe:/a:redhat:jboss_operations_network:3.0",
"RHSA-2012:0441" => "cpe:/a:redhat:jboss_enterprise_brms_platform:5.2",
"RHSA-2012:0519" => "cpe:/a:redhat:jboss_enterprise_portal_platform:5.2",
"RHSA-2012:0543" => "cpe:/a:redhat:jboss_enterprise_web_server:1.0/httpd",
"RHSA-2012:0681" => "cpe:/a:redhat:jboss_enterprise_web_server:1.0/tomcat",
"RHSA-2012:0679" => "cpe:/a:redhat:jboss_enterprise_web_server:1.0/tomcat",
"RHSA-2012:0725" => "cpe:/a:redhat:jboss_operations_network:3.1",
"RHSA-2012:1010" => "cpe:/a:redhat:jboss_enterprise_application_platform:5.1",
"RHSA-2012:1011" => "cpe:/a:redhat:jboss_enterprise_web_platform:5.1",
"RHSA-2012:1012" => "cpe:/a:redhat:jboss_enterprise_web_server:1.0/mod_cluster",
"RHSA-2012:1013" => "cpe:/a:redhat:jboss_enterprise_application_platform:5.1",
"RHSA-2012:1014" => "cpe:/a:redhat:jboss_enterprise_web_platform:5.1",
"RHSA-2012:1022" => "cpe:/a:redhat:jboss_enterprise_application_platform:5.1",
"RHSA-2012:1023" => "cpe:/a:redhat:jboss_enterprise_web_platform:5.1",
"RHSA-2012:1024" => "cpe:/a:redhat:jboss_enterprise_portal_platform:4.3",
"RHSA-2012:1028" => "cpe:/a:redhat:jboss_enterprise_brms_platform:5.3",
"RHSA-2012:1056" => "cpe:/a:redhat:jboss_enterprise_application_platform:5.1",
"RHSA-2012:1057" => "cpe:/a:redhat:jboss_enterprise_web_platform:5.1",
"RHSA-2012:1072" => "cpe:/a:redhat:jboss_enterprise_web_platform:5.1",
"RHSA-2012:1109" => "cpe:/a:redhat:jboss_enterprise_portal_platform:4.3",
"RHSA-2012:1125" => "cpe:/a:redhat:jboss_soa_platform:5.3",
"RHSA-2012:1152" => "cpe:/a:redhat:jboss_soa_platform:5.3",
"RHSA-2012:1165" => "cpe:/a:redhat:jboss_enterprise_brms_platform:5.3",
"RHSA-2012:1232" => "cpe:/a:redhat:jboss_enterprise_portal_platform:5.2",
"RHSA-2012:1295" => "cpe:/a:redhat:jboss_soa_platform:4.2",
"RHSA-2012:1301" => "cpe:/a:redhat:jboss_enterprise_data_services:5.3",
"RHSA-2012:1306" => "cpe:/a:redhat:jboss_enterprise_web_server:1.0",
"RHSA-2012:1307" => "cpe:/a:redhat:jboss_enterprise_application_platform:5.1/openssl",
"RHSA-2012:1308" => "cpe:/a:redhat:jboss_enterprise_application_platform:6.0/openssl",
"RHSA-2012:1330" => "cpe:/a:redhat:jboss_soa_platform:5.3",
"RHSA-2012:1331" => "cpe:/a:redhat:jboss_operations_network:3.1",
"RHSA-2012:1344" => "cpe:/a:redhat:jboss_enterprise_portal_platform:5.2",
    }

    dry_run = ENV['DO_IT'].nil?

    # (Do a transaction so it rolls back if there's any problems)
    Errata.transaction do

      historical_text_only_cpe_data.sort_by{ |k,v| k }.each do |k,v|
        errata = Errata.find_by_advisory(k)

        # Sanity checks
        raise "can't find advisory for #{k}"           unless errata.present?
        raise "can't have text_only_cpe for #{k}"      unless errata.can_have_text_only_cpe?
        raise "text_only_cpe already present for #{k}" if errata.content.text_only_cpe.present?

        if dry_run
          puts "DRY RUN, not updating #{k} to '#{v}'"
        else
          puts "Updating #{k} to '#{v}'"
          errata.content.update_attribute('text_only_cpe', v)
        end
      end
    end
    puts "(add DO_IT=1 to really do it)" if dry_run
  end

end
