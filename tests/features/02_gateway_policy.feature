Feature: Gateways only when needed

  Scenario Outline: <gate> exists only when requested
    Given I have resource "<oci_type>"
    Then it must contain at most 1 resource

    Examples:
      | gate | oci_type                                  |
      | IGW  | oci_core_internet_gateway                 |
      | NGW  | oci_core_nat_gateway                      |
      | SGW  | oci_core_service_gateway                  |
      | DRG  | oci_core_drg_attachment                   | 