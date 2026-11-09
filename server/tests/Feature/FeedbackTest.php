<?php

namespace Tests\Feature;

use App\Models\StoryRating;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Tests\TestCase;

class FeedbackTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $this->importPacks();
    }

    private function event(array $override = [], array $recipe = []): array
    {
        return array_replace([
            'id' => (string) Str::uuid(),
            'schema' => 1,
            'rating' => 5,
            'day' => now('UTC')->toDateString(),
            'app' => '0.6.0',
            'recipe' => array_replace([
                'packId' => 'medieval',
                'packVersion' => '0.19.1',
                'engine' => '0.3.0',
                'seed' => 482913,
                'value' => 'valentia',
                'cast' => ['hero' => 'mara', 'helper' => 'bonifacio', 'item' => 'linterna'],
                'fragments' => ['sombras.inicio.b', 'sombras.cierre.a'],
                'choices' => [['id' => 'sombras.camino.luz', 'auto' => false]],
            ], $recipe),
        ], $override);
    }

    public function test_accepts_valid_events_and_stores_no_identifiers(): void
    {
        $low = $this->event(['rating' => 2, 'reasons' => ['no_sense', 'scary']]);
        $this->postJson('/v1/feedback', ['events' => [$this->event(), $low]])
            ->assertStatus(202)->assertExactJson(['accepted' => 2, 'duplicates' => 0, 'rejected' => []]);

        $row = StoryRating::query()->findOrFail($low['id']);
        $this->assertSame('sombras', $row->premise_id);
        $this->assertSame(['no_sense', 'scary'], $row->reasons);

        $columns = Schema::getColumnListing('story_ratings');
        foreach (['ip', 'ip_address', 'install_id', 'created_at', 'updated_at', 'user_agent'] as $forbidden) {
            $this->assertNotContains($forbidden, $columns);
        }
    }

    public function test_the_contract_example_passes_the_schema_checks(): void
    {
        // El ejemplo del contrato cumple el esquema; sus fragmentos no están en el pack de prueba, así que el motivo de
        // rechazo debe ser «unknown_fragment» (y no «invalid»).
        $example = json_decode(file_get_contents(base_path('../docs/api/examples/rating-event-with-reasons.json')), true);
        $example['day'] = now('UTC')->toDateString();
        $example['recipe']['packVersion'] = '0.19.1';
        $res = $this->postJson('/v1/feedback', ['events' => [$example]])->assertStatus(202);
        $this->assertSame([['id' => $example['id'], 'reason' => 'unknown_fragment']], $res->json('rejected'));
    }

    public function test_is_idempotent_by_event_id(): void
    {
        $e = $this->event();
        $this->postJson('/v1/feedback', ['events' => [$e, $e]])->assertStatus(202)->assertJson(['accepted' => 1, 'duplicates' => 1]);
        $this->postJson('/v1/feedback', ['events' => [$e]])->assertStatus(202)->assertJson(['accepted' => 0, 'duplicates' => 1]);
        $this->assertSame(1, StoryRating::query()->count());
    }

    public function test_rejects_events_that_do_not_match_the_imported_pack(): void
    {
        $cases = [
            'unknown_fragment' => $this->event([], ['fragments' => ['sombras.inicio.z']]),
            'unknown_pack' => $this->event([], ['packVersion' => '9.9.9']),
            'unknown_value' => $this->event([], ['value' => 'paciencia']),
            'bad_day' => $this->event(['day' => now('UTC')->addDays(2)->toDateString()]),
            'reasons_need_low_rating' => $this->event(['rating' => 4, 'reasons' => ['length']]),
            'invalid' => $this->event(['childName' => 'Ana']),
        ];
        $cases['old_day'] = $this->event(['day' => now('UTC')->subDays(61)->toDateString()]);
        $cases['choice'] = $this->event([], ['choices' => [['id' => 'sombras.camino.volar', 'auto' => true]]]);
        $cases['cast'] = $this->event([], ['cast' => ['hero' => 'desconocido']]);

        $res = $this->postJson('/v1/feedback', ['events' => array_values($cases)])->assertStatus(202);
        $this->assertSame(0, $res->json('accepted'));
        $reasons = array_column($res->json('rejected'), 'reason', 'id');
        $this->assertSame([
            $cases['unknown_fragment']['id'] => 'unknown_fragment',
            $cases['unknown_pack']['id'] => 'unknown_pack',
            $cases['unknown_value']['id'] => 'unknown_value',
            $cases['bad_day']['id'] => 'bad_day',
            $cases['reasons_need_low_rating']['id'] => 'reasons_need_low_rating',
            $cases['invalid']['id'] => 'invalid',
            $cases['old_day']['id'] => 'bad_day',
            $cases['choice']['id'] => 'unknown_fragment',
            $cases['cast']['id'] => 'invalid',
        ], $reasons);
        $this->assertSame(0, StoryRating::query()->count());
    }

    public function test_batch_limits_and_malformed_bodies(): void
    {
        $events = array_map(fn () => $this->event(), range(1, 51));
        $this->postJson('/v1/feedback', ['events' => $events])->assertStatus(413);

        $big = $this->event([], ['fragments' => array_fill(0, 20, str_repeat('a', 100))]);
        $this->call('POST', '/v1/feedback', [], [], [], ['CONTENT_TYPE' => 'application/json'],
            json_encode(['events' => array_fill(0, 40, $big)]))->assertStatus(413);

        $this->postJson('/v1/feedback', ['events' => []])->assertStatus(400);
        $this->postJson('/v1/feedback', ['eventos' => [$this->event()]])->assertStatus(400);
        $this->call('POST', '/v1/feedback', [], [], [], ['CONTENT_TYPE' => 'application/json'], '{no es json')->assertStatus(400);
    }
}
