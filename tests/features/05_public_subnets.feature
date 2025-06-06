Feature: Public subnet settings

  Background:
    Given terraform plan has completed

  # Bastion & public LB subnets should allow public IPs
  Scenario Outline: <subnet> allows public IPs
    Given I have resource "oci_core_subnet" as "pub"
    When its value for "display_name" matches the pattern "<subnet>.*"
    Then its value for "prohibit_public_ip_on_vnic" must be false

    Examples:
      | subnet  |
      | bastion |
      | plb     | 