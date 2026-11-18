<?php

namespace Tests\Feature;

use App\Models\Premise;
use Tests\TestCase;

class ContentQueueTest extends TestCase
{
    public function test_queue_needs_the_token_and_reports_results(): void
    {
        $this->importPacks();
        config(['mininoches.deploy_token' => 'secreto-largo']);
        $this->getJson('/internal/contenido/cola')->assertForbidden();

        $p = Premise::query()->where('ref', 'medieval:sombras')->sole();
        $draft = $p->data;
        $draft['title'] = 'Nuevo título';
        $p->fill(['draft' => $draft, 'draft_catalog' => ['id' => 'medieval:sombras'], 'draft_op' => 'guardar',
            'draft_state' => Premise::QUEUED, 'draft_updated_at' => now()])->save();
        $failing = Premise::query()->where('ref', 'medieval:campana')->sole();
        $failing->fill(['draft' => $failing->data, 'draft_op' => 'guardar', 'draft_state' => Premise::QUEUED, 'draft_updated_at' => now()])->save();

        $items = $this->withToken('secreto-largo')->getJson('/internal/contenido/cola')->assertOk()->json('items');
        $this->assertCount(2, $items);
        $this->assertSame('Nuevo título', collect($items)->firstWhere('ref', 'medieval:sombras')['premise']['title']);

        $this->withToken('secreto-largo')->postJson('/internal/contenido/resultado', ['results' => [
            ['ref' => 'medieval:sombras', 'ok' => true],
            ['ref' => 'medieval:campana', 'ok' => false, 'error' => 'El motor dice: falta {helper}'],
        ]])->assertOk()->assertJson(['updated' => 2]);
        $this->assertSame(Premise::PUBLISHING, $p->fresh()->draft_state);
        $this->assertSame(Premise::FAILED, $failing->fresh()->draft_state);
        $this->assertStringContainsString('falta {helper}', $failing->fresh()->draft_error);
    }
}
