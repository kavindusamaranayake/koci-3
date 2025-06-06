Feature: Service-Gateway routed from private subnets

  Background:
    Given terraform plan has completed

  Scenario: SGW present → at least one SERVICE_CIDR_BLOCK route
    Given I have resource "oci_core_service_gateway"
    And it must contain at least 1 resource

    Given I have resource "oci_core_route_table" as "rt"
    Then its value for "route_rules[*].destination_type" must contain "SERVICE_CIDR_BLOCK" 