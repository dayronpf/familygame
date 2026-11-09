<?php

/*
 * Configuración propia de Mininoches. Cada valor sale de una variable de entorno documentada en .env.example.
 */
return [

    // Carpeta con los paquetes de cuentos ({id}/pack.json). Por defecto, la del repositorio.
    'packs_path' => env('MININOCHES_PACKS_PATH') ?: base_path('../content/packs'),

    // Cuentos gratis al importar por primera vez (luego se cambian en el panel).
    'default_free' => array_values(array_filter(array_map('trim', explode(',', (string) env(
        'MININOCHES_DEFAULT_FREE',
        'medieval:sombras,mar:galletas_todos,cosmos:chispa_perdida'
    ))))),

    // Clave secreta Ed25519 (base64, 64 bytes o semilla de 32) con la que se firman los derechos.
    'signing_key' => env('ENTITLEMENT_SIGNING_KEY'),

    // Google Play Developer API (androidpublisher v3).
    'google' => [
        'package' => env('GOOGLE_PLAY_PACKAGE', 'com.calderodecuentos.cuentos'),
        // Ruta al JSON de la cuenta de servicio (o el JSON mismo si empieza por «{»).
        'service_account_json' => env('GOOGLE_SERVICE_ACCOUNT_JSON'),
        'rtdn_token' => env('GOOGLE_RTDN_TOKEN'),
        // Si la compra llega sin confirmar (acknowledge), el servidor la confirma para que Google no la reembolse.
        'acknowledge' => (bool) env('GOOGLE_ACKNOWLEDGE', true),
        'api_base' => 'https://androidpublisher.googleapis.com/androidpublisher/v3',
        'token_uri' => 'https://oauth2.googleapis.com/token',
        'scope' => 'https://www.googleapis.com/auth/androidpublisher',
    ],

    // Detrás de un proxy o balanceador: «*» o lista de IP separadas por comas, para que el límite de ritmo vea la
    // IP real del teléfono (que nunca se guarda).
    'trusted_proxies' => env('TRUSTED_PROXIES'),

    // Límites de ritmo por minuto (por IP, que solo se usa cifrada y en caché temporal; nunca se guarda).
    'rate_limits' => [
        'api' => (int) env('RATE_LIMIT_API', 60),
        'verify' => (int) env('RATE_LIMIT_VERIFY', 20),
        'redeem' => (int) env('RATE_LIMIT_REDEEM', 5),
        'feedback' => (int) env('RATE_LIMIT_FEEDBACK', 30),
        'webhooks' => (int) env('RATE_LIMIT_WEBHOOKS', 300),
        'admin_login' => (int) env('RATE_LIMIT_ADMIN_LOGIN', 5),
    ],

    'feedback' => [
        'max_events' => 50,
        'max_bytes' => 65536,
        'max_age_days' => 60,
    ],
];
