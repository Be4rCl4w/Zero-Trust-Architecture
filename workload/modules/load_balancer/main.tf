resource "azurerm_lb" "lb" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "internalIPfrontend"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.app_lb_private_ip
  }
}

resource "azurerm_lb_backend_address_pool" "pool" {
  name            = "vmss-backend-pool"
  loadbalancer_id = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "http" {
  name                = "http-probe"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Http"
  port                = 3000
  request_path        = "/api/health"
  interval_in_seconds = 10
  number_of_probes    = 3
}

resource "azurerm_lb_rule" "http" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 3000
  frontend_ip_configuration_name = "internalIPfrontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pool.id]
  probe_id                       = azurerm_lb_probe.http.id
}
