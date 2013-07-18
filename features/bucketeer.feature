Feature: My bootstrapped app kinda works
  In order to get going on coding my awesome app
  I want to have aruba and cucumber setup
  So I don't have to do it myself

  Scenario: App just runs
    When I get help for "bucketeer"
    Then the exit status should be 0
    And the banner should be present
    And the banner should document that this app takes options
    And the following options should be documented:
      |--version|
      |--region|
    And the banner should document that this app's arguments are:
      | name | which is required |

  Scenario: Create bucket
    Given a bucket with the name "testbucket" does not exist
    When I run `bucketeer testbucket`
    Then the exit status should be 0
    And the response should show a bucketname and access keys
