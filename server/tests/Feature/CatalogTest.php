<?php

namespace Tests\Feature;

use App\Models\Premise;
use App\Models\StoryRating;
use Illuminate\Support\Str;
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

    public function test_ratings_show_the_average_only_with_five_or_more(): void
    {
        $rate = function (string $pack, string $premise, int $rating): void {
            StoryRating::query()->create([
                'event_id' => (string) Str::uuid(), 'pack_id' => $pack, 'pack_version' => '1.0.0',
                'premise_id' => $premise, 'engine' => '1', 'seed' => 1, 'value_id' => 'v',
                'cast_ids' => [], 'fragment_ids' => [], 'rating' => $rating,
                'rated_on' => '2026-11-19', 'app_version' => '1.0.0', 'received_on' => '2026-11-19',
            ]);
        };
        foreach ([5, 5, 4, 5, 4] as $r) {
            $rate('mar', 'faro', $r);
        }
        foreach ([1, 2] as $r) {
            $rate('mar', 'pulpo', $r);
        }
        $this->getJson('/v1/catalog')->assertOk()
            ->assertJsonPath('ratings.mar:faro', ['avg' => 4.6, 'n' => 5])
            ->assertJsonMissingPath('ratings.mar:pulpo');
    }

    public function test_ratings_is_an_object_even_when_empty(): void
    {
        $body = $this->get('/v1/catalog')->assertOk()->getContent();
        $this->assertStringContainsString('"ratings":{}', $body);
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
