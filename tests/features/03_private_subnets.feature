Feature: Private subnet hygiene

  Scenario: no public IPs on private subnets
    Given I have resource "oci_core_subnet" as "sub"
    When its value for "prohibit_public_ip_on_vnic" is true
    Then its value must be true 