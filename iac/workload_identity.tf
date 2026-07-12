# ==============================================================================
# STUDIO PUPSI: ENTERPRISE IDENTITY INTEGRATION (AZURE WORKLOAD IDENTITY)
# Target Architecture: Schlüssellose Authentifizierung für den Rust-Validator
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

# 1. Lokale Variablen für das Kubernetes Namespace- und ServiceAccount-Mapping
locals {
  k8s_namespace       = "pupsi-core-infrastructure"
  k8s_service_account = "pupsi-validator-sa"
}

# 2. Datenquelle des bestehenden AKS Clusters abfragen (für den OIDC-Issuer-URL)
data "azurerm_kubernetes_cluster" "aks" {
  name                = "pupsi-identity-perimeter-cluster"
  resource_group_name = "pupsi-security-rg"
}

# 3. Erstellung der Managed Identity für den K8s-Pod (Keine Passwörter/Secrets!)
resource "azurerm_user_assigned_identity" "validator_identity" {
  name                = "id-pupsi-rust-validator-prod"
  resource_group_name = "pupsi-security-rg"
  location            = "westeurope"
}

# 4. Der Brückenschlag (Federated Identity Credential): Vertrauensstellung einrichten
resource "azurerm_federated_identity_credential" "k8s_bridge" {
  name                = "fed-pupsi-k8s-validator-trust"
  resource_group_name = "pupsi-security-rg"
  audience            = ["api://AzureADTokenExchange"]
  
  # Der OIDC Provider des AKS Clusters authentifiziert den K8s Service Account
  issuer              = data.azurerm_kubernetes_cluster.aks.oidc_issuer_url
  
  # Harte Einschränkung: Nur DIESER spezifische K8s-Pod im Namespace darf die Identität annehmen
  subject             = "system:serviceaccount:${local.k8s_namespace}:${local.k8s_service_account}"
}

# 5. RBAC: Der Identität Zugriff auf den Key Vault gewähren (Beispielhaft für DevSecOps)
resource "azurerm_key_vault_access_policy" "kv_policy" {
#  key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/pupsi-security-rg/providers/Microsoft.KeyVault/vaults/pupsi-vault"
  tenant_id    = azurerm_user_assigned_identity.validator_identity.tenant_id
  object_id    = azurerm_user_assigned_identity.validator_identity.principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# ==============================================================================
# OUTPUTS FÜR DAS KUBERNETES MANIFEST
# ==============================================================================
output "workload_client_id" {
  description = "Diese Client-ID muss als Annotation im K8s ServiceAccount hinterlegt werden!"
  value       = azurerm_user_assigned_identity.validator_identity.client_id
}

