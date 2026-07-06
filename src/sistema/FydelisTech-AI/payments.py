import requests
import os

def verificar_pagamento_paypal(order_id):
    """
    Valida se um pagamento no PayPal foi concluído com sucesso.
    Utiliza autenticação OAuth2 e a API v2 de ordens do PayPal.
    """
    client_id = os.getenv("PAYPAL_CLIENT_ID")
    client_secret = os.getenv("PAYPAL_CLIENT_SECRET")
    
    # URL base (Use 'https://api-m.paypal.com' para produção)
    base_url = "https://api-m.sandbox.paypal.com"
    
    # 1. Obter Token de Acesso (OAuth2)
    auth_response = requests.post(
        f"{base_url}/v1/oauth2/token",
        auth=(client_id, client_secret),
        data={'grant_type': 'client_credentials'}
    )
    
    if auth_response.status_code != 200:
        return False
        
    access_token = auth_response.json().get('access_token')
    
    # 2. Consultar detalhes da Ordem
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    
    response = requests.get(
        f"{base_url}/v2/checkout/orders/{order_id}", 
        headers=headers
    )
    
    # 3. Validar se a ordem existe e está concluída
    if response.status_code == 200:
        order_data = response.json()
        return order_data.get('status') == 'COMPLETED'
    
    return False