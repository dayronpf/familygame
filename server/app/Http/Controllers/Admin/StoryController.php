<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Pack;
use App\Models\Premise;
use App\Models\StoryRating;
use App\Services\Catalog;
use App\Services\PackImporter;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\View\View;
use RuntimeException;

class StoryController extends Controller
{
    public function index(Request $request): View
    {
        $filters = $request->only(['pack', 'age', 'moral', 'status', 'free', 'q']);
        $query = Premise::query()->with('pack')->where('in_pack', true);
        if (! empty($filters['pack'])) {
            $query->where('pack_id', $filters['pack']);
        }
        if (! empty($filters['moral'])) {
            $query->where('value', $filters['moral']);
        }
        if (! empty($filters['status'])) {
            $query->where('review_status', $filters['status']);
        }
        if (($filters['free'] ?? '') !== '') {
            $query->where('is_free', $filters['free'] === '1');
        }
        if (! empty($filters['q'])) {
            $query->where(fn ($q) => $q->where('title', 'like', '%'.$filters['q'].'%')->orWhere('ref', 'like', '%'.$filters['q'].'%'));
        }
        $premises = $query->orderBy('pack_id')->orderBy('position')->get();
        if (! empty($filters['age'])) {
            $premises = $premises->filter(fn (Premise $p) => in_array($filters['age'], $p->ages ?? [], true))->values();
        }

        $ratings = StoryRating::query()->selectRaw('pack_id, premise_id, count(*) as n, avg(rating) as avg')
            ->groupBy('pack_id', 'premise_id')->get()->keyBy(fn ($r) => $r->pack_id.':'.$r->premise_id);

        $packs = Pack::query()->orderBy('id')->get();

        return view('admin.stories.index', [
            'premises' => $premises,
            'ratings' => $ratings,
            'packs' => $packs,
            'morals' => $packs->flatMap(fn (Pack $p) => $p->morals)->unique('id')->sortBy('name')->values(),
            'ages' => ['2-3', '4-5', '6-8', '9-12'],
            'filters' => $filters,
            'removed' => Premise::query()->where('in_pack', false)->count(),
        ]);
    }

    public function show(Premise $premise): View
    {
        $rows = StoryRating::query()->where('pack_id', $premise->pack_id)->where('premise_id', $premise->premise_id)
            ->get(['rating', 'reasons', 'fragment_ids', 'pack_version']);

        $distribution = array_fill(1, 5, 0);
        $reasons = array_fill_keys(array_keys(StoryRating::REASONS), 0);
        $byFragment = [];
        foreach ($rows as $r) {
            $distribution[$r->rating]++;
            foreach ($r->reasons ?? [] as $reason) {
                $reasons[$reason] = ($reasons[$reason] ?? 0) + 1;
            }
            foreach ($r->fragment_ids as $f) {
                $byFragment[$f]['n'] = ($byFragment[$f]['n'] ?? 0) + 1;
                $byFragment[$f]['sum'] = ($byFragment[$f]['sum'] ?? 0) + $r->rating;
            }
        }

        return view('admin.stories.show', [
            'premise' => $premise->load('pack'),
            'stats' => [
                'count' => $rows->count(),
                'avg' => $rows->avg('rating'),
                'distribution' => $distribution,
                'reasons' => $reasons,
                'byFragment' => $byFragment,
                'versions' => $rows->pluck('pack_version')->unique()->sort()->values(),
            ],
            'logs' => AuditLog::query()->where('subject_type', 'Premise')->where('subject_id', (string) $premise->id)
                ->latest('id')->limit(20)->get(),
        ]);
    }

    public function review(Request $request, Premise $premise, Catalog $catalog): RedirectResponse
    {
        $data = $request->validate([
            'status' => ['required', Rule::in(Premise::STATUSES)],
            'notes' => ['nullable', 'string', 'max:5000'],
        ]);
        $before = ['status' => $premise->review_status, 'notes' => $premise->review_notes];
        $premise->fill([
            'review_status' => $data['status'],
            'review_notes' => $data['notes'] ?? null,
            'reviewed_at' => now(),
        ])->save();
        $catalog->bump();
        AuditLog::record('story.review', $premise, [
            'ref' => $premise->ref, 'from' => $before['status'], 'to' => $data['status'],
            'notesChanged' => $before['notes'] !== ($data['notes'] ?? null),
        ]);

        return back()->with('ok', match ($data['status']) {
            Premise::APPROVED => 'Cuento aprobado.',
            Premise::REJECTED => 'Cuento rechazado: la app dejará de mostrarlo cuando actualice el catálogo.',
            default => 'Cuento marcado como pendiente.',
        });
    }

    public function toggleFree(Premise $premise, Catalog $catalog): RedirectResponse
    {
        $premise->is_free = ! $premise->is_free;
        $premise->save();
        $catalog->bump();
        AuditLog::record('story.free', $premise, ['ref' => $premise->ref, 'free' => $premise->is_free]);

        return back()->with('ok', $premise->is_free ? 'Ahora es gratis.' : 'Ya no es gratis.');
    }

    public function import(PackImporter $importer): RedirectResponse
    {
        try {
            $result = $importer->import(config('mininoches.packs_path'));
        } catch (RuntimeException $e) {
            return back()->with('error', $e->getMessage());
        }
        AuditLog::record('packs.import', null, $result);
        $summary = collect($result['packs'])->map(fn ($p) => "{$p['id']} {$p['version']} ({$p['premises']} cuentos, {$p['created']} nuevos)")->implode(' · ');

        return back()->with('ok', "Importado: {$summary}.");
    }
}
