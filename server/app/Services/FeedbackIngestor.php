<?php

namespace App\Services;

use App\Models\PackVersion;
use App\Models\StoryRating;
use Carbon\CarbonImmutable;
use Illuminate\Database\UniqueConstraintViolationException;

/**
 * Valida y guarda un lote de valoraciones (docs/api/feedback.openapi.yaml y docs/12 §8).
 *
 * Cada evento se valida por separado: los inválidos se devuelven en `rejected` y el resto se guarda. Nada de IP, hora
 * ni identificadores: solo el día que eligió la app y el día de recepción.
 */
class FeedbackIngestor
{
    private const UUID4 = '/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/';

    private const SEMVER = '/^\d+\.\d+\.\d+$/';

    private const SLUG = '/^[a-z][a-z0-9_]{0,39}$/';

    private const EVENT_KEYS = ['id', 'schema', 'rating', 'day', 'app', 'reasons', 'recipe'];

    private const RECIPE_KEYS = ['packId', 'packVersion', 'engine', 'seed', 'value', 'cast', 'fragments', 'choices'];

    /** @var array<string, array|null> manifiestos ya leídos en esta petición */
    private array $manifests = [];

    /**
     * @param  list<mixed>  $events
     * @return array{accepted: int, duplicates: int, rejected: list<array{id: string, reason: string}>}
     */
    public function ingest(array $events): array
    {
        $accepted = 0;
        $duplicates = 0;
        $rejected = [];
        $seen = [];
        $today = CarbonImmutable::now('UTC')->startOfDay();

        foreach ($events as $event) {
            $id = is_array($event) && is_string($event['id'] ?? null) ? $event['id'] : '';
            $reason = $this->check($event, $today);
            if ($reason !== null) {
                $rejected[] = ['id' => $id, 'reason' => $reason];

                continue;
            }
            if (isset($seen[$id]) || StoryRating::query()->whereKey($id)->exists()) {
                $duplicates++;

                continue;
            }
            $seen[$id] = true;
            $recipe = $event['recipe'];
            try {
                StoryRating::query()->create([
                    'event_id' => $id,
                    'pack_id' => $recipe['packId'],
                    'pack_version' => $recipe['packVersion'],
                    'premise_id' => str_contains($recipe['fragments'][0], '.') ? explode('.', $recipe['fragments'][0])[0] : null,
                    'engine' => $recipe['engine'],
                    'seed' => $recipe['seed'],
                    'value_id' => $recipe['value'],
                    'cast_ids' => $recipe['cast'],
                    'fragment_ids' => array_values($recipe['fragments']),
                    'choices' => isset($recipe['choices']) ? array_values($recipe['choices']) : null,
                    'rating' => $event['rating'],
                    'reasons' => isset($event['reasons']) ? array_values($event['reasons']) : null,
                    'rated_on' => $event['day'],
                    'app_version' => $event['app'],
                    'received_on' => $today->toDateString(),
                ]);
            } catch (UniqueConstraintViolationException) {
                $duplicates++; // otro envío del mismo evento llegó a la vez

                continue;
            }
            $accepted++;
        }

        return ['accepted' => $accepted, 'duplicates' => $duplicates, 'rejected' => $rejected];
    }

    /** Devuelve el motivo de rechazo o null si el evento es válido. */
    private function check(mixed $e, CarbonImmutable $today): ?string
    {
        if (! is_array($e) || array_is_list($e) || array_diff(array_keys($e), self::EVENT_KEYS)) {
            return 'invalid';
        }
        foreach (['id', 'schema', 'rating', 'day', 'app', 'recipe'] as $k) {
            if (! array_key_exists($k, $e)) {
                return 'invalid';
            }
        }
        if (! is_string($e['id']) || ! preg_match(self::UUID4, $e['id'])
            || $e['schema'] !== 1
            || ! is_int($e['rating']) || $e['rating'] < 1 || $e['rating'] > 5
            || ! is_string($e['day']) || ! preg_match('/^\d{4}-\d{2}-\d{2}$/', $e['day'])
            || ! is_string($e['app']) || ! preg_match(self::SEMVER, $e['app'])) {
            return 'invalid';
        }

        if (array_key_exists('reasons', $e)) {
            $r = $e['reasons'];
            if (! is_array($r) || ! array_is_list($r) || count($r) < 1 || count($r) > 5
                || count(array_unique($r, SORT_REGULAR)) !== count($r)
                || array_diff($r, array_keys(StoryRating::REASONS))) {
                return 'invalid';
            }
        }

        $recipe = $e['recipe'];
        if (! is_array($recipe) || array_is_list($recipe) || array_diff(array_keys($recipe), self::RECIPE_KEYS)) {
            return 'invalid';
        }
        foreach (['packId', 'packVersion', 'engine', 'seed', 'value', 'cast', 'fragments'] as $k) {
            if (! array_key_exists($k, $recipe)) {
                return 'invalid';
            }
        }
        if (! is_string($recipe['packId']) || ! preg_match('/^[a-z0-9_-]{1,40}$/', $recipe['packId'])
            || ! is_string($recipe['packVersion']) || ! preg_match(self::SEMVER, $recipe['packVersion'])
            || ! is_string($recipe['engine']) || ! preg_match(self::SEMVER, $recipe['engine'])
            || ! is_int($recipe['seed']) || $recipe['seed'] < 0 || $recipe['seed'] > 4294967295
            || ! is_string($recipe['value']) || ! preg_match(self::SLUG, $recipe['value'])) {
            return 'invalid';
        }
        $cast = $recipe['cast'];
        if (! is_array($cast) || ($cast !== [] && array_is_list($cast)) || count($cast) > 8) {
            return 'invalid';
        }
        foreach ($cast as $slot => $castId) {
            if (! is_string($slot) || ! is_string($castId) || ! preg_match(self::SLUG, $castId)) {
                return 'invalid';
            }
        }
        $fragments = $recipe['fragments'];
        if (! is_array($fragments) || ! array_is_list($fragments) || count($fragments) < 1 || count($fragments) > 20) {
            return 'invalid';
        }
        foreach ($fragments as $f) {
            if (! is_string($f) || strlen($f) > 100 || ! preg_match('/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*){0,2}$/', $f)) {
                return 'invalid';
            }
        }
        $choices = $recipe['choices'] ?? [];
        if (! is_array($choices) || ! array_is_list($choices) || count($choices) > 2) {
            return 'invalid';
        }
        foreach ($choices as $c) {
            if (! is_array($c) || array_diff(array_keys($c), ['id', 'auto']) || ! isset($c['id'])
                || ! array_key_exists('auto', $c) || ! is_bool($c['auto'])
                || ! is_string($c['id']) || strlen($c['id']) > 100
                || ! preg_match('/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*){2}$/', $c['id'])) {
                return 'invalid';
            }
        }

        // Reglas que el esquema no puede expresar.
        $day = CarbonImmutable::createFromFormat('!Y-m-d', $e['day'], 'UTC');
        if ($day === false || $day->format('Y-m-d') !== $e['day']
            || $day->greaterThan($today)
            || $day->lessThan($today->subDays((int) config('mininoches.feedback.max_age_days', 60)))) {
            return 'bad_day';
        }
        if (isset($e['reasons']) && $e['rating'] > 3) {
            return 'reasons_need_low_rating';
        }

        $manifest = $this->manifest($recipe['packId'], $recipe['packVersion']);
        if ($manifest === null) {
            return 'unknown_pack';
        }
        if (! in_array($recipe['value'], $manifest['values'] ?? [], true)) {
            return 'unknown_value';
        }
        $known = array_flip($manifest['fragments'] ?? []);
        foreach ($fragments as $f) {
            if (! isset($known[$f])) {
                return 'unknown_fragment';
            }
        }
        $knownChoices = array_flip($manifest['choices'] ?? []);
        foreach ($choices as $c) {
            if (! isset($knownChoices[$c['id']])) {
                return 'unknown_fragment';
            }
        }
        $castIds = array_flip($manifest['castIds'] ?? []);
        foreach ($cast as $castId) {
            if (! isset($castIds[$castId])) {
                return 'invalid';
            }
        }

        return null;
    }

    private function manifest(string $packId, string $version): ?array
    {
        $key = "{$packId}@{$version}";
        if (! array_key_exists($key, $this->manifests)) {
            $this->manifests[$key] = PackVersion::query()
                ->where('pack_id', $packId)->where('version', $version)->first()?->manifest;
        }

        return $this->manifests[$key];
    }
}
