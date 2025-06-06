Feature: NSG rules are stateful by default

  Scenario: stateless flag is false
    Given I have resource "oci_core_network_security_group_security_rule"
    When it has attribute "stateless"
    Then its value must be false 