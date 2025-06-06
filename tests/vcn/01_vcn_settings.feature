Feature: VCN definition

  Scenario: single VCN with correct CIDR
    Given I have resource "oci_core_vcn"
    Then it must contain exactly 1 resource
    And  its value for "cidr_blocks[0]" must be "10.2.0.0/16" 