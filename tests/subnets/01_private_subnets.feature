Feature: Private subnet hygiene

  Scenario: private subnets block public IPs
    Given I have resource "oci_core_subnet"
    When its value for "prohibit_public_ip_on_vnic" is true
    Then its value must be true 