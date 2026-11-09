<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Tablas de Mininoches: contenido importado, catálogo, compras, derechos, códigos, valoraciones y auditoría.
 *
 * Privacidad (docs/09 §7 y docs/12 §8): ninguna tabla tiene columnas de IP, nombre o edad del niño, ni texto que
 * envíe la app. Las valoraciones no llevan identificador de instalación ni hora.
 */
return new class extends Migration
{
    public function up(): void
    {
        // Ajustes sencillos clave → valor (p. ej. la versión del catálogo).
        Schema::create('settings', function (Blueprint $table) {
            $table->string('key')->primary();
            $table->text('value')->nullable();
            $table->timestamps();
        });

        // Paquete lógico (medieval, mar, cosmos) con los datos de su última importación.
        Schema::create('packs', function (Blueprint $table) {
            $table->string('id', 40)->primary();
            $table->string('name');
            $table->string('version', 20);
            $table->unsignedSmallInteger('schema');
            $table->string('language', 10)->nullable();
            $table->string('age_band', 20)->nullable();
            $table->json('morals');
            $table->timestamp('imported_at')->nullable();
            $table->timestamps();
        });

        // Cada versión importada de un pack, con los códigos válidos para comprobar las valoraciones.
        // Se conservan las versiones viejas: los teléfonos que no se han actualizado siguen enviando la suya.
        Schema::create('pack_versions', function (Blueprint $table) {
            $table->id();
            $table->string('pack_id', 40);
            $table->string('version', 20);
            $table->string('sha256', 64);
            $table->json('manifest'); // {fragments, choices, values, castIds}
            $table->timestamp('imported_at');
            $table->unique(['pack_id', 'version']);
        });

        // Un cuento (premisa) con todo su texto, para que el SuperAdmin lo revise.
        Schema::create('premises', function (Blueprint $table) {
            $table->id();
            $table->string('pack_id', 40)->index();
            $table->string('premise_id', 60);
            $table->string('ref', 101)->unique(); // «paquete:premisa»
            $table->string('title');
            $table->string('value', 40)->index(); // id de la enseñanza
            $table->json('ages');
            $table->json('beats');
            $table->unsignedSmallInteger('beat_count')->default(0);
            $table->unsignedSmallInteger('variant_count')->default(0);
            $table->unsignedSmallInteger('position')->default(0);
            $table->string('pack_version', 20);
            $table->boolean('in_pack')->default(true); // false si desapareció del pack en la última importación
            $table->string('review_status', 20)->default('pendiente')->index(); // pendiente | aprobado | rechazado
            $table->text('review_notes')->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->boolean('is_free')->default(false)->index();
            $table->timestamps();
            $table->unique(['pack_id', 'premise_id']);
        });

        // Productos de suscripción que la app muestra (el precio lo pone la tienda).
        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->string('product_id', 100);
            $table->string('platform', 10); // android | ios
            $table->string('base_plan', 60)->nullable();
            $table->string('period', 5); // P1M | P1Y
            $table->unsignedSmallInteger('trial_days')->default(0);
            $table->boolean('active')->default(true);
            $table->unsignedSmallInteger('position')->default(0);
            $table->timestamps();
            $table->unique(['product_id', 'platform', 'base_plan']);
        });

        // Compras verificadas (o intentadas) con la tienda.
        Schema::create('purchases', function (Blueprint $table) {
            $table->id();
            $table->uuid('install_id')->index(); // última instalación que la presentó
            $table->string('platform', 10);
            $table->string('product_id', 100);
            $table->string('token_hash', 64)->nullable(); // sha256 del purchaseToken (para buscar)
            $table->text('token_encrypted')->nullable(); // el token cifrado con APP_KEY (para volver a consultar)
            $table->string('transaction_id', 100)->nullable(); // iOS
            $table->string('state', 60); // estado de la tienda, p. ej. SUBSCRIPTION_STATE_ACTIVE
            $table->boolean('premium')->default(false);
            $table->boolean('trial')->default(false);
            $table->boolean('auto_renewing')->default(false);
            $table->boolean('test_purchase')->default(false);
            $table->string('base_plan', 60)->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->json('raw_response')->nullable();
            $table->timestamp('last_verified_at')->nullable();
            $table->timestamps();
            $table->unique(['platform', 'token_hash']);
        });

        // Derecho vigente por instalación. Guarda por separado lo que dice la tienda y lo que dan los códigos;
        // el derecho efectivo es el que dure más (App\Models\Entitlement::effective()).
        Schema::create('entitlements', function (Blueprint $table) {
            $table->id();
            $table->uuid('install_id')->unique();
            $table->foreignId('purchase_id')->nullable()->index();
            $table->string('store_source', 10)->nullable(); // google | apple
            $table->string('store_product_id', 100)->nullable();
            $table->boolean('store_premium')->default(false);
            $table->boolean('store_trial')->default(false);
            $table->boolean('store_auto_renewing')->default(false);
            $table->timestamp('store_expires_at')->nullable();
            $table->timestamp('code_expires_at')->nullable();
            $table->timestamps();
        });

        // Códigos de canje creados en el panel (regalos, socios, escuelas).
        Schema::create('redeem_codes', function (Blueprint $table) {
            $table->id();
            $table->string('code', 32)->unique();
            $table->unsignedInteger('days');
            $table->unsignedInteger('max_uses')->default(1);
            $table->unsignedInteger('uses_count')->default(0);
            $table->timestamp('expires_at')->nullable();
            $table->boolean('active')->default(true);
            $table->string('note')->nullable();
            $table->timestamps();
        });

        Schema::create('code_redemptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('redeem_code_id')->index();
            $table->uuid('install_id')->index();
            $table->timestamp('redeemed_at');
            $table->unique(['redeem_code_id', 'install_id']);
        });

        // Notificaciones de las tiendas (Google RTDN, Apple Server Notifications v2).
        Schema::create('store_notifications', function (Blueprint $table) {
            $table->id();
            $table->string('platform', 10);
            $table->string('type', 60)->nullable();
            $table->string('token_hash', 64)->nullable()->index();
            $table->json('payload');
            $table->string('result', 60)->nullable();
            $table->timestamp('processed_at')->nullable();
            $table->timestamps();
        });

        // Valoraciones anónimas (docs/12 §8). Sin instalación, IP ni hora: solo días.
        Schema::create('story_ratings', function (Blueprint $table) {
            $table->uuid('event_id')->primary(); // idempotencia
            $table->string('pack_id', 40);
            $table->string('pack_version', 20);
            $table->string('premise_id', 60)->nullable(); // prefijo del primer fragmento (esquema 2)
            $table->string('engine', 20);
            $table->unsignedBigInteger('seed');
            $table->string('value_id', 40);
            $table->json('cast_ids');
            $table->json('fragment_ids');
            $table->json('choices')->nullable();
            $table->unsignedTinyInteger('rating');
            $table->json('reasons')->nullable();
            $table->date('rated_on');
            $table->string('app_version', 20);
            $table->date('received_on');
            $table->index(['pack_id', 'pack_version']);
            $table->index(['pack_id', 'premise_id']);
        });

        // Registro de lo que hace el SuperAdmin en el panel (sin IP).
        Schema::create('audit_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable();
            $table->string('action', 60);
            $table->string('subject_type', 60)->nullable();
            $table->string('subject_id', 120)->nullable();
            $table->json('details')->nullable();
            $table->timestamp('created_at');
        });
    }

    public function down(): void
    {
        foreach (['audit_logs', 'story_ratings', 'store_notifications', 'code_redemptions', 'redeem_codes',
            'entitlements', 'purchases', 'products', 'premises', 'pack_versions', 'packs', 'settings'] as $t) {
            Schema::dropIfExists($t);
        }
    }
};
