<?php

use App\Http\Controllers\Api\CatalogController;
use App\Http\Controllers\Api\EntitlementController;
use App\Http\Controllers\Api\FeedbackController;
use App\Http\Controllers\Api\PurchaseController;
use App\Http\Controllers\Api\RedeemController;
use App\Http\Controllers\Api\WebhookController;
use Illuminate\Support\Facades\Route;

/*
 * API pública de la app (JSON, sin cookies ni sesiones). Contratos: docs/api/store.openapi.yaml y
 * docs/api/feedback.openapi.yaml. Los límites de ritmo están en AppServiceProvider.
 */
Route::prefix('v1')->group(function () {
    Route::get('catalog', [CatalogController::class, 'show'])->middleware('throttle:mn-api');
    Route::get('entitlements', [EntitlementController::class, 'show'])->middleware('throttle:mn-api');
    Route::post('purchases/verify', [PurchaseController::class, 'verify'])->middleware('throttle:mn-verify');
    Route::post('redeem', [RedeemController::class, 'redeem'])->middleware('throttle:mn-redeem');
    Route::post('feedback', [FeedbackController::class, 'store'])->middleware('throttle:mn-feedback');
    Route::post('webhooks/google', [WebhookController::class, 'google'])->middleware('throttle:mn-webhooks');
    Route::post('webhooks/apple', [WebhookController::class, 'apple'])->middleware('throttle:mn-webhooks');
});
