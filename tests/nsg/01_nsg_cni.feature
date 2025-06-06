Feature: CNI-specific NSG rules

  Background:
    Given terraform plan has completed

  Scenario: Calico (UDP 4789)
    Given I have resource "oci_core_network_security_group_security_rule"
    When its value for "description" is "Calico VXLAN 4789"
    Then its value for "protocol" must be "17"

  Scenario: Flannel (UDP 6081)
    Given I have resource "oci_core_network_security_group_security_rule"
    When its value for "description" is "Flannel UDP 6081"
    Then its value for "protocol" must be "17" 