@javascript @bug_1360531 @metaxor @mxr
Feature: Container Tab for Docker Advisory

  Background:
    Given I am a "devel" user

  @bug_1371334 @javascript
  Scenario: Failing to contact Lightblue
    When I view details of Advisory "RHBA-2016:1890-04"
    Then I can see "Container" Tab
    When I click on "Container" Tab
    Then I see Errata fetching data from Lightblue
    Then I see an alert message "Unable to contact Lightblue, returning cached data"
    And  details of all Builds in the Advisory
    And  details about Associated Advisories and CVE
    And  I am able to see the details about Bugs
    And  I can view tags by clicking tags icon
    And  I can view comparison data by clicking info icon

