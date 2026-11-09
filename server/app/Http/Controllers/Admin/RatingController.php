<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Premise;
use App\Models\StoryRating;
use Illuminate\Http\Request;
use Illuminate\View\View;

class RatingController extends Controller
{
    public function index(Request $request): View
    {
        $minCount = max(1, (int) $request->query('min', 1));

        $byPack = StoryRating::query()
            ->selectRaw('pack_id, count(*) as n, avg(rating) as avg, sum(case when rating <= 3 then 1 else 0 end) as low')
            ->groupBy('pack_id')->orderBy('pack_id')->get();

        $byPremise = StoryRating::query()
            ->selectRaw('pack_id, premise_id, count(*) as n, avg(rating) as avg, sum(case when rating <= 3 then 1 else 0 end) as low')
            ->groupBy('pack_id', 'premise_id')->havingRaw('count(*) >= ?', [$minCount])
            ->orderBy('avg')->get();

        // Motivos de las notas bajas, en total y por cuento.
        $reasons = array_fill_keys(array_keys(StoryRating::REASONS), 0);
        $reasonsByPremise = [];
        StoryRating::query()->whereNotNull('reasons')->select(['pack_id', 'premise_id', 'reasons'])
            ->lazyById(500, 'event_id')->each(function (StoryRating $r) use (&$reasons, &$reasonsByPremise) {
                foreach ($r->reasons ?? [] as $reason) {
                    $reasons[$reason] = ($reasons[$reason] ?? 0) + 1;
                    $reasonsByPremise["{$r->pack_id}:{$r->premise_id}"][$reason] = ($reasonsByPremise["{$r->pack_id}:{$r->premise_id}"][$reason] ?? 0) + 1;
                }
            });

        $premises = Premise::query()->get(['id', 'ref', 'title'])->keyBy('ref');

        return view('admin.ratings.index', [
            'total' => StoryRating::query()->count(),
            'avg' => StoryRating::query()->avg('rating'),
            'byPack' => $byPack,
            'byPremise' => $byPremise,
            'reasons' => $reasons,
            'reasonsByPremise' => $reasonsByPremise,
            'premises' => $premises,
            'minCount' => $minCount,
        ]);
    }
}
