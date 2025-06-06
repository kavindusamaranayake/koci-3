Feature: VCN definition

  Background:
    Given terraform plan has completed

  Scenario: Exactly one VCN with the expected CIDR
    Given I have resource "oci_core_vcn"
    Then it must contain exactly 1 resource
    And its value for "cidr_blocks[0]" must be "10.2.0.0/16" 