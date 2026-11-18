{{-- Estado de un cuento: si sale en la app y si tiene cambios sin publicar. --}}
@php($vis = $premise->visibility())
@php($visBadge = [
    'visible' => ['green', 'En la app'], 'oculto' => ['red', 'Oculto'], 'fuera' => ['slate', 'Fuera de la app'],
    'retirado' => ['slate', 'Retirado del pack'], 'nuevo' => ['violet', 'Nuevo'],
][$vis])
@if ($premise->draft_op === 'eliminar')
    <x-badge color="red" dot>Se eliminará</x-badge>
@else
    <x-badge :color="$visBadge[0]" dot>{{ $visBadge[1] }}</x-badge>
@endif
@if ($premise->review_status === \App\Models\Premise::PENDING && $vis !== 'nuevo' && empty($compact))
    <x-badge color="amber">Por revisar</x-badge>
@endif
@if ($premise->draft_state === \App\Models\Premise::DRAFT)
    <x-badge color="indigo">Borrador</x-badge>
@elseif (in_array($premise->draft_state, [\App\Models\Premise::QUEUED, \App\Models\Premise::PUBLISHING], true))
    <x-badge color="blue">{{ $premise->draft_state === \App\Models\Premise::PUBLISHING ? 'Publicando…' : 'En cola' }}</x-badge>
@elseif ($premise->draft_state === \App\Models\Premise::FAILED)
    <x-badge color="red" title="{{ $premise->draft_error }}">Error al publicar</x-badge>
@endif
