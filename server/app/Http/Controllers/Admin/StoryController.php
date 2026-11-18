<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Pack;
use App\Models\Premise;
use App\Models\StoryRating;
use App\Services\Catalog;
use App\Services\PackImporter;
use App\Services\StoryEditor;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\View\View;
use RuntimeException;

/**
 * Cuentos: lista con búsqueda, filtros y acciones en lote; ficha; editor con borradores; cola de publicación.
 *
 * Lo que cambia de inmediato en la app (por el catálogo, GET /v1/catalog): ocultar/mostrar y «Gratis».
 * Lo que necesita publicarse (texto, escenas, cuentos nuevos, eliminar del todo): va a la cola y lo publica
 * tools/content/publish_panel.py (docs/37).
 */
class StoryController extends Controller
{
    private const TABS = [
        'todos' => 'Todos',
        'app' => 'En la app',
        'pendientes' => 'Por revisar',
        'ocultos' => 'Ocultos',
        'cambios' => 'Sin publicar',
    ];

    private const SORTS = ['titulo' => 'title', 'pack' => 'pack_id', 'edad' => 'ages', 'escenas' => 'beat_count', 'actualizado' => 'updated_at', 'valoracion' => 'rating_avg'];

    public function index(Request $request): View
    {
        $tab = array_key_exists($request->query('vista'), self::TABS) ? $request->query('vista') : 'todos';
        $filters = [
            'q' => trim((string) $request->query('q', '')),
            'pack' => (string) $request->query('pack', ''),
            'edad' => (string) $request->query('edad', ''),
            'ensenanza' => (string) $request->query('ensenanza', ''),
            'gratis' => (string) $request->query('gratis', ''),
        ];
        $sort = array_key_exists($request->query('orden'), self::SORTS) ? $request->query('orden') : 'pack';
        $dir = $request->query('dir') === 'desc' ? 'desc' : 'asc';
        $perPage = in_array((int) $request->query('por_pagina'), [25, 50, 100], true) ? (int) $request->query('por_pagina') : 25;

        $base = Premise::query()->listed();
        $this->applyFilters($base, $filters);

        $counts = [];
        foreach (array_keys(self::TABS) as $t) {
            $counts[$t] = $this->applyTab(clone $base, $t)->count();
        }

        $query = $this->applyTab(clone $base, $tab)->with('pack')
            ->addSelect(['rating_avg' => StoryRating::query()->selectRaw('avg(rating)')
                ->whereColumn('story_ratings.pack_id', 'premises.pack_id')->whereColumn('story_ratings.premise_id', 'premises.premise_id')])
            ->addSelect(['rating_n' => StoryRating::query()->selectRaw('count(*)')
                ->whereColumn('story_ratings.pack_id', 'premises.pack_id')->whereColumn('story_ratings.premise_id', 'premises.premise_id')]);
        $column = self::SORTS[$sort];
        $query->orderBy($column === 'rating_avg' ? 'rating_avg' : "premises.{$column}", $dir);
        if ($sort === 'pack') {
            $query->orderBy('premises.position');
        }

        $packs = Pack::query()->orderBy('id')->get();

        return view('admin.stories.index', [
            'premises' => $query->paginate($perPage)->withQueryString(),
            'packs' => $packs,
            'morals' => $packs->flatMap(fn (Pack $p) => $p->morals ?? [])->unique('id')->sortBy('name')->values(),
            'ages' => Premise::AGES,
            'filters' => $filters,
            'tab' => $tab,
            'tabs' => self::TABS,
            'counts' => $counts,
            'sort' => $sort,
            'dir' => $dir,
            'perPage' => $perPage,
            'queue' => [
                'drafts' => Premise::query()->where('draft_state', Premise::DRAFT)->count(),
                'queued' => Premise::query()->whereIn('draft_state', [Premise::QUEUED, Premise::PUBLISHING])->count(),
                'failed' => Premise::query()->where('draft_state', Premise::FAILED)->count(),
            ],
        ]);
    }

    private function applyFilters(Builder $q, array $f): void
    {
        if ($f['q'] !== '') {
            $like = '%'.str_replace(['%', '_'], ['\%', '\_'], $f['q']).'%';
            // En algunas bases el JSON guarda los acentos escapados (\u00e1): se busca también así.
            $escaped = '%'.str_replace(['\\', '%', '_'], ['\\\\', '\%', '\_'], trim(json_encode($f['q']), '"')).'%';
            $q->where(fn ($w) => $w->where('title', 'like', $like)->orWhere('ref', 'like', $like)
                ->orWhere('beats', 'like', $like)->orWhere('draft', 'like', $like)
                ->when($escaped !== $like, fn ($x) => $x->orWhere('beats', 'like', $escaped)->orWhere('draft', 'like', $escaped)));
        }
        if ($f['pack'] !== '') {
            $q->where('pack_id', $f['pack']);
        }
        if (in_array($f['edad'], Premise::AGES, true)) {
            $q->where('ages', 'like', '%"'.$f['edad'].'"%');
        }
        if ($f['ensenanza'] !== '') {
            $q->where('value', $f['ensenanza']);
        }
        if ($f['gratis'] !== '') {
            $q->where('is_free', $f['gratis'] === '1');
        }
    }

    private function applyTab(Builder $q, string $tab): Builder
    {
        return match ($tab) {
            'app' => $q->whereNotNull('catalog')->where('in_pack', true)->where('review_status', '!=', Premise::REJECTED),
            'pendientes' => $q->where('review_status', Premise::PENDING),
            'ocultos' => $q->where('review_status', Premise::REJECTED),
            'cambios' => $q->whereNotNull('draft_state'),
            default => $q,
        };
    }

    public function show(Request $request, Premise $premise, StoryEditor $editor): View
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
        $view = in_array($request->query('vista'), ['leer', 'valoraciones', 'historial'], true) ? $request->query('vista') : 'leer';
        // Con borrador se puede ver lo publicado o el borrador.
        $showDraft = $premise->draft !== null && $request->query('version') !== 'publicada';
        $story = $showDraft ? $premise->draft : ($premise->data ?? ['title' => $premise->title, 'beats' => $premise->beats]);

        return view('admin.stories.show', [
            'premise' => $premise->load('pack'),
            'story' => $story,
            'storyCatalog' => $showDraft ? $premise->draft_catalog : $premise->catalog,
            'showDraft' => $showDraft,
            'view' => $view,
            'stats' => [
                'count' => $rows->count(),
                'avg' => $rows->avg('rating'),
                'distribution' => $distribution,
                'reasons' => $reasons,
                'byFragment' => $byFragment,
                'versions' => $rows->pluck('pack_version')->unique()->sort()->values(),
            ],
            'logs' => AuditLog::query()->with('user')->where('subject_type', 'Premise')->where('subject_id', (string) $premise->id)
                ->latest('id')->limit(50)->get(),
        ]);
    }

    public function create(Request $request): View
    {
        $packs = Pack::query()->orderBy('id')->get();
        $from = $request->query('desde');
        $packId = $request->query('pack') ?: Premise::query()->whereKey($from)->value('pack_id') ?: $packs->first()?->id;

        return view('admin.stories.create', [
            'packs' => $packs,
            'packId' => $packId,
            'templates' => Premise::query()->where('in_pack', true)->whereNotNull('data')->orderBy('pack_id')->orderBy('title')
                ->get(['id', 'pack_id', 'title', 'ages', 'catalog']),
            'from' => $from,
        ]);
    }

    public function store(Request $request, StoryEditor $editor): RedirectResponse
    {
        $data = $request->validate([
            'title' => ['required', 'string', 'min:3', 'max:80'],
            'template' => ['required', 'integer', Rule::exists('premises', 'id')],
        ], ['template.required' => 'Elige el cuento que sirve de base.']);
        $from = Premise::query()->findOrFail($data['template']);
        $premise = $editor->duplicate($from, trim($data['title']));
        AuditLog::record('story.create', $premise, ['ref' => $premise->ref, 'from' => $from->ref]);

        return redirect()->route('admin.stories.edit', $premise)
            ->with('ok', "Cuento creado a partir de «{$from->title}». Cambia el texto y publícalo.");
    }

    public function duplicate(Premise $premise, StoryEditor $editor): RedirectResponse
    {
        $copy = $editor->duplicate($premise, mb_substr('Copia de '.$premise->title, 0, 80));
        AuditLog::record('story.create', $copy, ['ref' => $copy->ref, 'from' => $premise->ref]);

        return redirect()->route('admin.stories.edit', $copy)->with('ok', 'Copia creada como cuento nuevo (sin publicar).');
    }

    public function edit(Premise $premise, StoryEditor $editor): View
    {
        $story = $premise->editable();

        return view('admin.stories.edit', [
            'premise' => $premise->load('pack'),
            'story' => $story,
            'catalog' => $premise->editableCatalog(),
            'tokens' => $editor->usedTokens($story),
            'cast' => $story['cast'] ?? [],
            'ages' => Premise::AGES,
            'staging' => [
                'places' => $editor->places($story),
                'characters' => $editor->characters($story),
                'props' => array_values(array_unique(array_merge(
                    collect($premise->pack?->library['props'] ?? [])->pluck('id')->all(),
                    collect($story['beats'] ?? [])->flatMap(fn ($b) => collect($b['variants'] ?? [])->flatMap(fn ($v) => collect($v['scene']['props'] ?? [])->pluck('prop')))->all(),
                ))),
                'times' => StoryEditor::TIMES,
                'moods' => StoryEditor::MOODS,
                'clips' => StoryEditor::CLIPS,
            ],
        ]);
    }

    public function update(Request $request, Premise $premise, StoryEditor $editor): RedirectResponse
    {
        [$draft, $catalog] = $editor->build($premise, $request->all());
        $premise->fill([
            'draft' => $draft,
            'draft_catalog' => $catalog,
            'draft_op' => 'guardar',
            'draft_state' => $request->input('accion') === 'publicar' ? Premise::QUEUED : Premise::DRAFT,
            'draft_error' => null,
            'draft_updated_at' => now(),
        ]);
        if ($premise->isUnpublished()) {
            // Mientras no se publique, el título y los datos de la lista salen del borrador.
            $premise->fill(['title' => $draft['title'], 'value' => $draft['value'], 'ages' => $draft['ages'], 'beat_count' => count($draft['beats'])]);
        }
        $premise->save();
        AuditLog::record($premise->draft_state === Premise::QUEUED ? 'story.queue' : 'story.edit', $premise, ['ref' => $premise->ref]);

        return $premise->draft_state === Premise::QUEUED
            ? redirect()->route('admin.stories.show', $premise)->with('ok', 'Guardado y en cola para publicar. La app lo recibirá cuando termine la publicación.')
            : redirect()->route('admin.stories.edit', $premise)->with('ok', 'Borrador guardado. La app no cambia hasta que lo publiques.');
    }

    public function discard(Premise $premise): RedirectResponse
    {
        if ($premise->isUnpublished()) {
            return $this->destroy($premise, app(Catalog::class));
        }
        $premise->fill(Premise::CLEARED_DRAFT)->save();
        AuditLog::record('story.discard', $premise, ['ref' => $premise->ref]);

        return redirect()->route('admin.stories.show', $premise)->with('ok', 'Cambios descartados: queda lo publicado.');
    }

    public function publish(Premise $premise): RedirectResponse
    {
        if (! $premise->hasDraft()) {
            return back()->with('error', 'Este cuento no tiene cambios para publicar.');
        }
        $premise->fill(['draft_state' => Premise::QUEUED, 'draft_error' => null])->save();
        AuditLog::record('story.queue', $premise, ['ref' => $premise->ref, 'op' => $premise->draft_op]);

        return back()->with('ok', 'En cola para publicar.');
    }

    public function publishAll(): RedirectResponse
    {
        $ids = Premise::query()->whereIn('draft_state', [Premise::DRAFT, Premise::FAILED])->pluck('id');
        Premise::query()->whereIn('id', $ids)->update(['draft_state' => Premise::QUEUED, 'draft_error' => null]);
        AuditLog::record('story.queue_all', null, ['count' => $ids->count()]);

        return back()->with('ok', $ids->isEmpty() ? 'No hay cambios para publicar.' : "{$ids->count()} cuentos en cola para publicar.");
    }

    public function destroy(Premise $premise, Catalog $catalog): RedirectResponse
    {
        if ($premise->isUnpublished()) {
            $ref = $premise->ref;
            $premise->delete();
            AuditLog::record('story.delete', null, ['ref' => $ref, 'unpublished' => true]);

            return redirect()->route('admin.stories.index')->with('ok', 'Cuento eliminado.');
        }
        // Publicado: se oculta ya en la app y se quita del pack en la próxima publicación.
        $premise->fill([
            'review_status' => Premise::REJECTED,
            'draft' => $premise->editable(),
            'draft_catalog' => null,
            'draft_op' => 'eliminar',
            'draft_state' => Premise::QUEUED,
            'draft_error' => null,
            'draft_updated_at' => now(),
        ])->save();
        $catalog->bump();
        AuditLog::record('story.delete', $premise, ['ref' => $premise->ref]);

        return redirect()->route('admin.stories.index')
            ->with('ok', "«{$premise->title}» ya no sale en la app y se eliminará del pack en la próxima publicación.");
    }

    public function restore(Premise $premise, Catalog $catalog): RedirectResponse
    {
        $premise->fill(Premise::CLEARED_DRAFT + ['review_status' => Premise::APPROVED])->save();
        $catalog->bump();
        AuditLog::record('story.restore', $premise, ['ref' => $premise->ref]);

        return back()->with('ok', 'Eliminación cancelada: el cuento vuelve a la app.');
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
            'review_notes' => $data['notes'] ?? $premise->review_notes,
            'reviewed_at' => now(),
        ])->save();
        $catalog->bump();
        AuditLog::record('story.review', $premise, [
            'ref' => $premise->ref, 'from' => $before['status'], 'to' => $data['status'],
            'notesChanged' => $before['notes'] !== $premise->review_notes,
        ]);

        return back()->with('ok', match ($data['status']) {
            Premise::APPROVED => 'Cuento aprobado.',
            Premise::REJECTED => 'Cuento oculto: la app dejará de mostrarlo cuando actualice el catálogo.',
            default => 'Cuento marcado como por revisar.',
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

    public function bulk(Request $request, Catalog $catalog): RedirectResponse
    {
        $data = $request->validate([
            'ids' => ['required', 'array', 'min:1'],
            'ids.*' => ['integer'],
            'accion' => ['required', Rule::in(['aprobar', 'ocultar', 'mostrar', 'gratis', 'pago', 'publicar'])],
        ], ['ids.required' => 'Selecciona al menos un cuento.']);
        $q = Premise::query()->whereIn('id', $data['ids']);
        $n = match ($data['accion']) {
            'aprobar' => $q->update(['review_status' => Premise::APPROVED, 'reviewed_at' => now()]),
            'ocultar' => $q->update(['review_status' => Premise::REJECTED, 'reviewed_at' => now()]),
            'mostrar' => $q->where('review_status', Premise::REJECTED)->whereNull('draft_op')
                ->update(['review_status' => Premise::APPROVED, 'reviewed_at' => now()]),
            'gratis' => $q->update(['is_free' => true]),
            'pago' => $q->update(['is_free' => false]),
            'publicar' => $q->whereIn('draft_state', [Premise::DRAFT, Premise::FAILED])->update(['draft_state' => Premise::QUEUED, 'draft_error' => null]),
        };
        if ($data['accion'] !== 'publicar') {
            $catalog->bump();
        }
        AuditLog::record('story.bulk', null, ['action' => $data['accion'], 'ids' => $data['ids'], 'changed' => $n]);
        $labels = ['aprobar' => 'aprobados', 'ocultar' => 'ocultos', 'mostrar' => 'visibles otra vez', 'gratis' => 'ahora gratis', 'pago' => 'ahora de pago', 'publicar' => 'en cola para publicar'];

        return back()->with('ok', "{$n} cuentos {$labels[$data['accion']]}.");
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
