<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /** notificationUUID de Apple (App Store Server Notifications v2), para no procesar dos veces la misma. */
    public function up(): void
    {
        Schema::table('store_notifications', function (Blueprint $table) {
            $table->string('notification_id', 64)->nullable()->after('platform');
            $table->unique(['platform', 'notification_id']);
        });
    }

    public function down(): void
    {
        Schema::table('store_notifications', function (Blueprint $table) {
            $table->dropUnique(['platform', 'notification_id']);
            $table->dropColumn('notification_id');
        });
    }
};
