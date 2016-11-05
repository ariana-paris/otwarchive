Feature: Admin Find Users page

  Background:
    Given I have loaded the "roles" fixture
      And the following activated users exist
        | login | email     |
        | userA | a@ao3.org |
        | userB | b@bo3.org |
      And the user "userB" exists and has the role "archivist"
      And I am logged in as an admin

  Scenario: The default page for the Admin section should be the Find Users page
    Then I should see "Find Users"

  Scenario: The Find Users page should perform a partial match on name
    When I fill in "query" with "user"
      And I submit
    Then I should see "userA"
      And I should see "userB"

  Scenario: The Find Users page should perform a partial match by email
    When I fill in "query" with "bo3"
      And I submit
    Then I should see "userB"
      But I should not see "userA"

  Scenario: The Find Users page should perform an exact match by role
    When I select "Archivist" from "role"
      And I submit
    Then I should see "userB"
      But I should not see "userA"

  Scenario: The Find Users should display an appropriate message if no users are found
    When I fill in "query" with "co3"
      And I submit
    Then I should see "0 users found"

  # Bulk Email Search
  Scenario: The Bulk Email Search page should find an exact match
    When I go to the Bulk Email Search page
      And I fill in "Email addresses *" with "a@ao3.org"
    Then I should see "userA"
      But I should not see "userB"
