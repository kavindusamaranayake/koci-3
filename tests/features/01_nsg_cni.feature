Feature: CNI-specific NSG rules

  Background:
    # The value of cni_type is surfaced in the rule description – see locals.cni_udp_rules
    Given terraform plan has completed

  Scenario: Calico – only UDP 4789 present
    Given I have resource "oci_core_network_security_group_security_rule" as "rule"
    When its value for "description" is "Calico VXLAN 4789"
    Then its value for "protocol" must be "17"
    And  its value for "direction" must be "INGRESS"

  Scenario: Flannel – UDP 6081 present
    Given I have resource "oci_core_network_security_group_security_rule" as "rule"
    When its value for "description" is "Flannel UDP 6081"
    Then its value for "protocol" must be "17"
    And  its value for "direction" must be "INGRESS" 