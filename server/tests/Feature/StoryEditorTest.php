<?php

namespace Tests\Feature;

use App\Models\Premise;
use App\Models\User;
use Tests\TestCase;

class StoryEditorTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $this->importPacks();
        $this->artisan('mininoches:admin', ['email' => 'duena@mininoches.app', '--password' => 'una-clave-muy-larga']);
        $this->actingAs(User::query()->sole());
    }

    private function form(Premise $p, array $over = []): array
    {
        $story = $p->editable();

        return array_replace([
            'title' => $story['title'],
            'lesson' => 'Pedir ayuda está bien.',
            'value' => $story['value'],
            'ages' => $story['ages'],
            'beats' => collect($story['beats'])->map(fn ($b) => [
                'id' => $b['id'],
                'variants' => collect($b['variants'])->map(fn ($v) => ['id' => $v['id'], 'text' => $v['text']])->all(),
            ])->all(),
        ], $over);
    }

    public function test_list_searches_paginates_and_sorts(): void
    {
        $this->get('/admin/cuentos?q=campana')->assertOk()->assertSee('La campana rota')->assertDontSee('Las sombras del cuarto');
        $this->get('/admin/cuentos?orden=titulo&dir=desc&por_pagina=25')->assertOk();
        $this->get('/admin/cuentos?vista=cambios')->assertOk()->assertSee('No hay cuentos con estos filtros');
    }

    public function test_edit_saves_a_draft_without_touching_the_published_text(): void
    {
        $p = Premise::query()->where('ref', 'medieval:sombras')->sole();
        // Los packs reales llevan la puesta en escena en cada variante; el de prueba no: se le pone una.
        $data = $p->data;
        foreach ($data['beats'] as $b => $beat) {
            foreach ($beat['variants'] as $v => $variant) {
                $data['beats'][$b]['variants'][$v]['scene'] = ['bg' => 'cuarto', 'mood' => 'calm'];
            }
        }
        $p->forceFill(['data' => $data])->save();
        $published = $p->data;
        $form = $this->form($p, ['title' => 'Las sombras que bailan']);
        $form['beats'][0]['variants'][0]['text'] = '{hero} vio una sombra en la pared y se rió muy bajito, sin miedo.';
        // Una escena nueva al final copia la puesta en escena de la anterior.
        $form['beats'][] = ['id' => '', 'variants' => [['id' => '', 'text' => 'Y al final {hero} se durmió tranquil{hero.o}, abrazando su almohada.']]];

        $this->put("/admin/cuentos/{$p->id}", $form + ['accion' => 'guardar'])->assertRedirect("/admin/cuentos/{$p->id}/editar");
        $p->refresh();
        $this->assertSame(Premise::DRAFT, $p->draft_state);
        $this->assertSame('Las sombras que bailan', $p->draft['title']);
        $this->assertSame($published, $p->data, 'lo publicado no cambia hasta publicar');
        $beats = $p->draft['beats'];
        $last = end($beats);
        $this->assertSame('escena_'.count($beats), $last['id']);
        $this->assertArrayHasKey('scene', $last['variants'][0]);
        $this->assertArrayHasKey('scene', $p->draft['beats'][0]['variants'][0], 'la escena editada conserva su dibujo');

        $this->get("/admin/cuentos/{$p->id}")->assertOk()->assertSee('Las sombras que bailan')->assertSee('cambios sin publicar');
        $this->get("/admin/cuentos/{$p->id}?version=publicada")->assertOk()->assertSee($published['title']);
        $this->get('/admin/cuentos?vista=cambios')->assertSee('medieval:sombras');

        $this->post("/admin/cuentos/{$p->id}/publicar")->assertRedirect();
        $this->assertSame(Premise::QUEUED, $p->fresh()->draft_state);
    }

    public function test_editor_rejects_unknown_tokens_short_text_and_too_few_scenes(): void
    {
        $p = Premise::query()->where('ref', 'medieval:sombras')->sole();
        $form = $this->form($p);
        $form['beats'][0]['variants'][0]['text'] = 'Hola {dragon_inventado}, ¿qué tal estás hoy?';
        $form['beats'][1]['variants'][0]['text'] = 'Corto';
        $this->put("/admin/cuentos/{$p->id}", $form)->assertSessionHasErrors(['beats.0.variants.0.tokens', 'beats.1.variants.0.text']);

        $form = $this->form($p, ['beats' => array_slice($this->form($p)['beats'], 0, 2)]);
        $this->put("/admin/cuentos/{$p->id}", $form)->assertSessionHasErrors('beats');
        $this->assertNull($p->fresh()->draft);
    }

    public function test_create_from_a_template_edit_and_delete_before_publishing(): void
    {
        $template = Premise::query()->where('ref', 'medieval:sombras')->sole();
        $this->get('/admin/cuentos/nuevo')->assertOk()->assertSee('Elige el cuento base');
        $this->post('/admin/cuentos', ['title' => 'El búho que no dormía', 'template' => $template->id])->assertRedirect();
        $new = Premise::query()->where('origin', 'panel')->sole();
        $this->assertSame('medieval:el_buho_que_no_dormia', $new->ref);
        $this->assertTrue($new->isUnpublished());
        $this->get("/admin/cuentos/{$new->id}/editar")->assertOk()->assertSee('Cuento nuevo');
        $this->get('/admin/cuentos?q=búho')->assertOk()->assertSee('El búho que no dormía');

        $this->delete("/admin/cuentos/{$new->id}")->assertRedirect('/admin/cuentos');
        $this->assertNull(Premise::query()->find($new->id));
    }

    public function test_deleting_a_published_story_hides_it_now_and_queues_the_removal(): void
    {
        $p = Premise::query()->where('ref', 'medieval:campana')->sole();
        $this->delete("/admin/cuentos/{$p->id}")->assertRedirect('/admin/cuentos');
        $p->refresh();
        $this->assertSame('eliminar', $p->draft_op);
        $this->assertSame(Premise::QUEUED, $p->draft_state);
        $this->assertContains('medieval:campana', $this->getJson('/v1/catalog')->json('hiddenStories'));

        $this->post("/admin/cuentos/{$p->id}/restaurar")->assertRedirect();
        $this->assertNull($p->fresh()->draft_op);
        $this->assertNotContains('medieval:campana', $this->getJson('/v1/catalog')->json('hiddenStories'));
    }

    public function test_bulk_actions(): void
    {
        $ids = Premise::query()->where('pack_id', 'medieval')->pluck('id')->all();
        $this->post('/admin/cuentos/lote', ['ids' => $ids, 'accion' => 'ocultar'])->assertRedirect();
        $this->assertSame(count($ids), Premise::query()->whereIn('id', $ids)->where('review_status', Premise::REJECTED)->count());
        $this->post('/admin/cuentos/lote', ['ids' => $ids, 'accion' => 'mostrar'])->assertRedirect();
        $this->assertSame(0, Premise::query()->whereIn('id', $ids)->where('review_status', Premise::REJECTED)->count());
        $this->post('/admin/cuentos/lote', ['ids' => [], 'accion' => 'gratis'])->assertSessionHasErrors('ids');
    }

    public function test_reimport_clears_a_queued_draft_once_published(): void
    {
        $p = Premise::query()->where('ref', 'medieval:sombras')->sole();
        // Un borrador en cola idéntico a lo publicado se considera cumplido al importar.
        $p->fill(['draft' => $p->data, 'draft_op' => 'guardar', 'draft_state' => Premise::QUEUED])->save();
        $this->importPacks();
        $this->assertNull($p->fresh()->draft_state);
    }

    public function test_scene_staging_can_be_changed(): void
    {
        $p = Premise::query()->where('ref', 'medieval:sombras')->sole();
        $data = $p->data;
        $data['cast']['cuarto'] = ['kind' => 'place', 'ids' => ['cuarto']];
        foreach ($data['beats'] as $b => $beat) {
            foreach ($beat['variants'] as $v => $variant) {
                $data['beats'][$b]['variants'][$v]['scene'] = ['bg' => 'cuarto', 'mood' => 'calm', 'time' => 'dia',
                    'stage' => [['who' => 'hero', 'clip' => 'idle', 'x' => 0.4]], 'props' => [['prop' => 'linterna', 'near' => 'hero', 'dx' => 0.1]], 'light' => 'lamp'];
            }
        }
        $p->forceFill(['data' => $data])->save();
        $form = $this->form($p);
        $form['beats'][0]['scene'] = ['bg' => 'cuarto', 'time' => 'noche', 'mood' => 'sleep',
            'stage' => [['who' => 'hero', 'clip' => 'sleep']], 'props' => ['', 'linterna']];
        $form['beats'][] = ['id' => '', 'variants' => [['id' => '', 'text' => 'Y al final {hero} se durmió muy tranquilo.']]];
        $form['beats'][1]['scene'] = ['bg' => 'inventado', 'time' => '', 'stage' => [['who' => 'hero', 'clip' => 'talk'], ['who' => 'nadie', 'clip' => 'talk']], 'props' => ['']];

        $this->put("/admin/cuentos/{$p->id}", $form)->assertSessionHasNoErrors();
        $beats = $p->fresh()->draft['beats'];
        $s0 = $beats[0]['variants'][0]['scene'];
        $this->assertSame(['noche', 'sleep', 'lamp'], [$s0['time'], $s0['mood'], $s0['light']], 'cambia lo elegido y conserva lo demás');
        $this->assertSame('sleep', $s0['stage'][0]['clip']);
        $this->assertSame(0.4, $s0['stage'][0]['x'], 'el mismo personaje conserva su sitio');
        $this->assertSame(0.1, $s0['props'][0]['dx']);
        $s1 = $beats[1]['variants'][0]['scene'];
        $this->assertSame('cuarto', $s1['bg'], 'un lugar que no existe no se acepta');
        $this->assertArrayNotHasKey('time', $s1);
        $this->assertCount(1, $s1['stage'], 'un personaje que no existe no se agrega');
        $this->assertArrayNotHasKey('props', $s1);

        $this->get("/admin/cuentos/{$p->id}/editar")->assertOk()->assertSee('Dibujo de la escena')->assertSee('Para dormir');
    }
}
