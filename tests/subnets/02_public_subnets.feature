Feature: Public subnet settings

  Background:
    Given terraform plan has completed

  Scenario Outline: <subnet> allows public IPs
    Given I have resource "oci_core_subnet"
    When its value for "display_name" matches the pattern "<subnet>.*"
    Then its value for "prohibit_public_ip_on_vnic" must be false

    Examples:
      | subnet  |
      | bastion |
      | plb     |