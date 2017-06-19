@javascript
Feature: Advisory creation
  Background:
    Given I am a "devel" user

  Scenario: Clicking on RHSA type shows Impact dropdown
    Given I am on "Assisted Create" page
    And   I cannot see "Impact" selection
    When  I choose the Advisory Type: "Red Hat Security Advisory"
    Then  I can see "Impact" selection

    When  I select the "Product": "Red Hat Enterprise Linux Extras"
    Then  "Release" selection changes to "RHEL-7.0.0"

    When  I select the "Product": "Red Hat Enterprise Linux"
    Then  "Release" selection changes to "FAST5.7"

  @pdc
  Scenario: Clicking on PDC RHSA type shows Impact dropdown
    Given I am on "PDC Assisted Create" page
    And   I cannot see "Impact" selection
    When  I choose the Advisory Type: "Red Hat Security Advisory"
    Then  I can see "Impact" selection

    When  I select the "Product": "PDC Test Product"
    Then  "Release" selection changes to "PDCTestRelease"

    When  I select the "Product": "Product for PDC"
    Then  "Release" selection changes to "ReleaseForPDC"
