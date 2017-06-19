Feature: CPE management
  Background:
    Given I am an "admin" user
    And   have the "secalert" role:

  Scenario: products are linked
    Given I am on "CPE Management" page
    When  I select "RHEL-2.1" link
    Then  I should see the following in title:
      | Title     |
      | RHEL      |
      | [Product] |
      | Red Hat Enterprise Linux |

  Scenario: variants are linked
    Given I am on "CPE Management" page
    When  I select "2.1AW" link
    Then  I should see details about variant "2.1AW":
