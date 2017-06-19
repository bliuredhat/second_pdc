class AssignReleaseComponents < ActiveRecord::Migration
  def self.up
    warning = ''
    execute(<<-'eos') \
SELECT GROUP_CONCAT(id),package,`release`
FROM (
  SELECT e.id,p.name as 'package',r.name as 'release'
  FROM bugs b
  JOIN filed_bugs fb ON fb.bug_id=b.id
  JOIN errata_main e ON fb.errata_id=e.id
  JOIN release_components rc ON rc.package_id=b.package_id
  JOIN packages p ON p.id=rc.package_id
  JOIN releases r ON r.id=rc.release_id
  WHERE e.group_id=r.id
    AND r.type='QuarterlyUpdate'
    AND e.errata_type!='RHSA'
  GROUP BY e.id
) AS sub
GROUP BY `release`, package
HAVING COUNT(id)>1;
eos
    .each do |row|
      warning += "  #{row[2]} #{row[1]}: #{row[0]}\n"
    end

    unless warning.blank?
      puts <<-"eos"


******************* PLEASE NOTE *****************************

Existing advisories will be associated with a package,
based on their filed bugs.

The following packages have multiple associated advisories.
This is no longer allowed.
For these packages, the association will be set on the most
recently updated advisory.
Consider checking these advisories afterwards.

#{warning}

******************* END NOTE ********************************


eos
    end


    # For all unassigned release components, we assign them to the most recently
    # updated advisory containing a bug for that component.
    execute <<-'eos';
UPDATE release_components rc
SET errata_id=(
  SELECT fb.errata_id
  FROM bugs b
  JOIN filed_bugs fb ON fb.bug_id=b.id
  JOIN errata_main e ON fb.errata_id=e.id
  WHERE b.package_id=rc.package_id
    AND e.group_id=rc.release_id
  ORDER BY e.updated_at DESC
  LIMIT 1
)
WHERE errata_id IS NULL
eos
  end

  def self.down
    # There's no rollback, since we don't know which advisories had their errata_id assigned by us.
    # You can uncomment this if you want to do a mass test over all release components.
    #execute 'UPDATE release_components SET errata_id=NULL';
  end
end
