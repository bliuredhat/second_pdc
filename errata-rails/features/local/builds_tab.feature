Feature: builds tab

# TODO: fix this scenario to follow the cucumber guildeline:
# https://github.com/cucumber/cucumber/wiki/Cucumber-Backgrounder

  Scenario: Add builds to an advisory
    Given I am a "devel" user
    And   Advisory "RHBA-2014:16398-01" set to "NEW_FILES" state
    And   following builds to add:
      | Type         | Name             |
      | good         | mom-0.4.0-1.el6ev |
      | good         | org.ovirt.engine-jboss-modules-maven-plugin-1.0-2 |
      | no-listing   | python_cpopen-1.3-2.el6_5   |
      | non-rpm      | rhev-spice-guest-msi-4.11-1 |
      | non-existing | notexist-bla-1.2.3 |
      | bad-format   | bad-format         |

    And   following variants:
      |     Variants            |
      |RHEL-6-Workstation-RHEV  |
      |RHEL-6-ComputeNode-RHEV  |
      |RHEL-6-Client-RHEV       |
      |RHEL-6-Server-RHEV       |
      |RHEL-6-Server-RHEV-S-3.3 |
      |RHEL-6-Server-RHEV-S-3.4 |

    And   following product-versions to add builds:
      | Name              |
      | RHEL-6-RHEV       |
      | RHEL-6-RHEV-S-3.3 |
      | RHEL-6-RHEV-S-3.4 |
    And   mock brew service

    When  I visit "Builds" tab
    Then  progress bar should be hidden
    And   builds form is shown

    When  I add builds to product-versions
    Then  job tracker count should change by 1
    And   job runs

    When  I click on 'Find New Builds'
    Then  build errors are shown
    And   warning about missing product listings is shown for following:
      | warnings                                    |
      | RHEL-6-RHEV python_cpopen-1.3-2.el6_5       |
      | RHEL-6-RHEV-S-3.3 python_cpopen-1.3-2.el6_5 |
      | RHEL-6-RHEV-S-3.4 python_cpopen-1.3-2.el6_5 |
    And   each product version should have a warning badge

    When  I check all file types
    And   click on 'Save Builds'
    And   mappings are recomputed
    Then  no mapping are removed
    And   following mappings are added:
      |                          mappings  |
      |RHEL-6-RHEV, mom-0.4.0-1.el6ev, rpm |
      |RHEL-6-RHEV, org.ovirt.engine-jboss-modules-maven-plugin-1.0-2, rpm |
      |RHEL-6-RHEV, python_cpopen-1.3-2.el6_5, rpm |
      |RHEL-6-RHEV, rhev-spice-guest-msi-4.11-1, tar |
      |RHEL-6-RHEV-S-3.3, mom-0.4.0-1.el6ev, rpm |
      |RHEL-6-RHEV-S-3.3, org.ovirt.engine-jboss-modules-maven-plugin-1.0-2, rpm |
      |RHEL-6-RHEV-S-3.3, python_cpopen-1.3-2.el6_5, rpm |
      |RHEL-6-RHEV-S-3.3, rhev-spice-guest-msi-4.11-1, tar |
      |RHEL-6-RHEV-S-3.4, mom-0.4.0-1.el6ev, rpm |
      |RHEL-6-RHEV-S-3.4, org.ovirt.engine-jboss-modules-maven-plugin-1.0-2, rpm |
      |RHEL-6-RHEV-S-3.4, python_cpopen-1.3-2.el6_5, rpm |
      |RHEL-6-RHEV-S-3.4, rhev-spice-guest-msi-4.11-1, tar |
