<%=
#
# Including the zabbix config as commented out sql so the sql can be tested.
#
# To test the sql:
#   rake debug:sql_examples:run SQL=examples/sql/zabbix_stats.erb.sql Y=1
#
# To create the zabbix config (removing the comment markers with sed):
#   rake debug:sql_examples:run SQL=examples/sql/zabbix_stats.erb.sql Y=0 | sed 's/ *\/\* *//g' | sed 's/ *\*\/ *//g'
#

db_host = 'db01.db.eng.bos.redhat.com'
zabbix_command = %{HOME=/etc/zabbix mysql -s -N -h #{db_host} -D errata -u zabbix -pxxxxxxx -e}

%w[RhnTpsJob RhnQaTpsJob CdnTpsJob CdnQaTpsJob].map do |job_type|
  # (These other states are defined in tps_states.rb but are not used: PENDING INFO VERIFY)
  %w[NOT_STARTED INVALIDATED BUSY GOOD BAD WAIVED].map do |job_state|
    short_type = job_type.sub(/TpsJob$/,'')
    %{
      /* UserParameter=errata.tps.#{short_type}.#{job_state}[*], #{zabbix_command} " */
      SELECT
        COUNT(*) AS #{short_type}_#{job_state}
      FROM
        tpsjobs AS j
        JOIN tpsstates AS s ON j.state_id = s.id
        JOIN tpsruns AS r ON j.run_id = r.run_id
        JOIN errata_main AS e ON r.errata_id = e.id
      WHERE
        e.status in ('NEW_FILES', 'QE')
        AND j.type = '#{job_type}'
        AND s.state = '#{job_state}';
      /* " */

    }.gsub(/\n\s+/, ' ').strip

  end
end.flatten.join("\n") +
"\n\n" +
%w[RHSA RHBA RHEA].map do |errata_type|
  %w[NEW_FILES QE REL_PREP PUSH_READY IN_PUSH].map do |status|
    %{
      /* UserParameter=errata.advisory.#{errata_type}.#{status}[*], #{zabbix_command} " */
      SELECT
        COUNT(*) AS #{errata_type}_#{status}
      FROM
        errata_main
      WHERE
        errata_main.errata_type = '#{errata_type}'
        AND errata_main.status = '#{status}';
      /* " */

    }.gsub(/\n\s+/, ' ').strip
  end
end.flatten.join("\n")
%>
