<?php

use App\Http\Controllers\Admin\AuditController;
use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\CodeController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\ProductController;
use App\Http\Controllers\Admin\PurchaseController;
use App\Http\Controllers\Admin\RatingController;
use App\Http\Controllers\Admin\StoryController;
use Illuminate\Support\Facades\Route;

Route::redirect('/', '/admin');

/*
 * Panel del SuperAdmin (sesión + CSRF). No hay registro: el único usuario se crea con `php artisan mininoches:admin`.
 */
Route::prefix('admin')->name('admin.')->group(function () {
    Route::middleware('guest')->group(function () {
        Route::get('login', [AuthController::class, 'show'])->name('login');
        Route::post('login', [AuthController::class, 'login'])->name('login.post');
    });

    Route::middleware('auth')->group(function () {
        Route::post('logout', [AuthController::class, 'logout'])->name('logout');
        Route::get('/', [DashboardController::class, 'index'])->name('dashboard');

        Route::get('cuentos', [StoryController::class, 'index'])->name('stories.index');
        Route::get('cuentos/nuevo', [StoryController::class, 'create'])->name('stories.create');
        Route::post('cuentos', [StoryController::class, 'store'])->name('stories.store');
        Route::post('cuentos/importar', [StoryController::class, 'import'])->name('stories.import');
        Route::post('cuentos/lote', [StoryController::class, 'bulk'])->name('stories.bulk');
        Route::post('cuentos/publicar', [StoryController::class, 'publishAll'])->name('stories.publish_all');
        Route::get('cuentos/{premise}', [StoryController::class, 'show'])->name('stories.show');
        Route::get('cuentos/{premise}/editar', [StoryController::class, 'edit'])->name('stories.edit');
        Route::put('cuentos/{premise}', [StoryController::class, 'update'])->name('stories.update');
        Route::delete('cuentos/{premise}', [StoryController::class, 'destroy'])->name('stories.destroy');
        Route::post('cuentos/{premise}/duplicar', [StoryController::class, 'duplicate'])->name('stories.duplicate');
        Route::post('cuentos/{premise}/descartar', [StoryController::class, 'discard'])->name('stories.discard');
        Route::post('cuentos/{premise}/publicar', [StoryController::class, 'publish'])->name('stories.publish');
        Route::post('cuentos/{premise}/restaurar', [StoryController::class, 'restore'])->name('stories.restore');
        Route::post('cuentos/{premise}/revision', [StoryController::class, 'review'])->name('stories.review');
        Route::post('cuentos/{premise}/gratis', [StoryController::class, 'toggleFree'])->name('stories.free');

        Route::get('compras', [PurchaseController::class, 'index'])->name('purchases.index');
        Route::get('compras/{purchase}', [PurchaseController::class, 'show'])->name('purchases.show');

        Route::get('codigos', [CodeController::class, 'index'])->name('codes.index');
        Route::post('codigos', [CodeController::class, 'store'])->name('codes.store');
        Route::post('codigos/{code}/activo', [CodeController::class, 'toggle'])->name('codes.toggle');

        Route::get('valoraciones', [RatingController::class, 'index'])->name('ratings.index');

        Route::get('productos', [ProductController::class, 'index'])->name('products.index');
        Route::post('productos', [ProductController::class, 'store'])->name('products.store');
        Route::post('productos/{product}', [ProductController::class, 'update'])->name('products.update');

        Route::get('auditoria', [AuditController::class, 'index'])->name('audit.index');
    });
});
