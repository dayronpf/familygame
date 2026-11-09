@php($colors = ['pendiente' => 'bg-amber-100 text-amber-800', 'aprobado' => 'bg-emerald-100 text-emerald-800', 'rechazado' => 'bg-rose-100 text-rose-800'])
<span class="inline-block rounded-full px-2 py-0.5 text-xs font-medium {{ $colors[$status] ?? 'bg-slate-100' }}">{{ ucfirst($status) }}</span>
