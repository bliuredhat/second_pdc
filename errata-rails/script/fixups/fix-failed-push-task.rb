#!/usr/bin/env ruby

# Run this script by using rails runner
# RAILS_ENV=production rails runner \
#   scripts/production-issues/fix-failed-push-task.rb | tee fix-failed-push-task.rb

def main
  advisories = %w(
    2016:1900
    2016:1906
    2016:1907
    2016:1932
    2016:1933
    2016:1934
    2016:1935
    2016:1936
    2016:1937
    2016:1938
    2016:1939
    2016:1940
    2016:1941
    2016:1942
    2016:1943
    2016:1944
    2016:1945
    2016:1946
    2016:1947
    2016:1948
    2016:1949
    2016:1950
    2016:1951
    2016:1952
    2016:1953
    2016:1954
    2016:1955
    2016:1956
    2016:1957
    2016:1958
    2016:1959
    2016:1960
    2016:1961
    2016:1962
    2016:1963
    2016:1964
    2016:1965
    2016:1966
    2016:1967
    2016:1968
    2016:1969
    2016:1970
    2016:1971
    2016:1972
    2016:1973
    2016:1974
    2016:1975
    2016:1976
    2016:1979
  )

  puts "Number of advisories: #{advisories.length}"
  errata = advisories.uniq.map { |a| Errata.find_by_advisory(a) }

  errata.each do |e|
    puts "Fixing: ... Advisory #{e.id} #{e.fulladvisory}"
    failed_jobs = e.push_jobs.
                   where(:status => 'POST_PUSH_FAILED').
                   where("post_push_tasks LIKE '%move_pushed_errata%'")

    failed_jobs.each do |j|
      puts "  ... failed_job #{j.id}"
      j.status = 'POST_PUSH_PROCESSING'
      j.send(:append_to_log, 'Manual run for ticket #421460')
      j.save!

      j.run_post_push_tasks 'move_pushed_errata'
      j.reload
      puts "      status: #{j.status}"
    end
  end
end

main if __FILE__ == $0
