<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Edición de cuentos desde el panel: el cuento completo tal como está en el pack, su entrada en el catálogo de la app
 * y un borrador que se publica por la cola (docs/37).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('premises', function (Blueprint $table) {
            $table->json('data')->nullable()->after('beats');           // la premisa completa del pack.json
            $table->json('catalog')->nullable()->after('data');         // su entrada en el catálogo fijo, si está en la app
            $table->string('origin', 10)->default('pack')->after('catalog'); // pack | panel (creado en el panel)
            $table->json('draft')->nullable();                          // premisa editada, sin publicar
            $table->json('draft_catalog')->nullable();
            $table->string('draft_op', 10)->nullable();                 // guardar | eliminar
            $table->string('draft_state', 12)->nullable()->index();     // borrador | en_cola | error
            $table->text('draft_error')->nullable();
            $table->timestamp('draft_updated_at')->nullable();
            $table->timestamp('published_at')->nullable();
        });
        Schema::table('packs', function (Blueprint $table) {
            $table->json('library')->nullable()->after('morals');       // personajes, lugares y objetos (para el editor)
        });
    }

    public function down(): void
    {
        Schema::table('premises', function (Blueprint $table) {
            $table->dropColumn(['data', 'catalog', 'origin', 'draft', 'draft_catalog', 'draft_op', 'draft_state',
                'draft_error', 'draft_updated_at', 'published_at']);
        });
        Schema::table('packs', function (Blueprint $table) {
            $table->dropColumn('library');
        });
    }
};
