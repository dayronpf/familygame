<?php

namespace Tests\Feature;

use App\Models\Premise;
use App\Services\Catalog;
use Tests\TestCase;

class CatalogTest extends TestCase
{
    public function test_catalog_lists_the_three_default_free_stories_and_products(): void
    {
        $result = $this->importPacks();
        $this->assertSame(['demo: esquema 1 (solo se importa el esquema 2)'], $result['skipped']);

        $res = $this->getJson('/v1/catalog')->assertOk();
        $res->assertJson([
            'freeStories' => ['cosmos:chispa_perdida', 'mar:galletas_todos', 'medieval:sombras'],
            'hiddenStories' => [],
            'products' => [
                ['id' => 'mininoches_premium', 'platform' => 'android', 'basePlan' => 'anual', 'period' => 'P1Y', 'trialDays' => 7],
                ['id' => 'mininoches_premium', 'platform' => 'android', 'basePlan' => 'mensual', 'period' => 'P1M', 'trialDays' => 7],
            ],
        ]);
        $this->assertIsString($res->json('version'));
        $this->assertSame(Premise::PENDING, Premise::query()->where('ref', 'medieval:campana')->value('review_status'));
        $res->assertCookieMissing('laravel_session');
    }

    public function test_etag_returns_304_when_unchanged_and_changes_with_catalog(): void
    {
        $this->importPacks();
        $etag = $this->get('/v1/catalog')->assertOk()->headers->get('ETag');
        $this->assertNotEmpty($etag);

        $this->get('/v1/catalog', ['If-None-Match' => $etag])->assertStatus(304);

        app(Catalog::class)->bump();
        $this->get('/v1/catalog', ['If-None-Match' => $etag])->assertOk();
    }

    public function test_reimport_keeps_review_status_and_free_flag(): void
    {
        $this->importPacks();
        Premise::query()->where('ref', 'medieval:campana')->update(['review_status' => Premise::REJECTED, 'is_free' => true]);
        Premise::query()->where('ref', 'medieval:sombras')->update(['is_free' => false]);

        $this->importPacks();

        $this->getJson('/v1/catalog')->assertJson([
            'freeStories' => ['cosmos:chispa_perdida', 'mar:galletas_todos'],
            'hiddenStories' => ['medieval:campana'],
        ]);
    }
}
