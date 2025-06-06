Feature: NSG rules are stateful by default

  Background:
    Given terraform plan has completed

  Scenario: no stateless rules unless explicitly asked
    Given I have resource "oci_core_network_security_group_security_rule" as "rule"
    When it has attribute "stateless"
    Then its value must be false 