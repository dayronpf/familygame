<div data-variant>
    <input type="hidden" data-variant-id value="{{ $variant['id'] ?? '' }}">
    <div class="flex items-center gap-2 mb-1">
        <span class="text-xs font-medium text-slate-500" data-variant-label></span>
        <span data-count class="text-xs text-slate-400 tabular-nums ml-auto"></span>
        <button type="button" data-remove-variant class="hidden text-xs text-rose-600 hover:underline">Quitar versión</button>
    </div>
    <textarea rows="3" class="input leading-relaxed resize-none" placeholder="Escribe lo que pasa en esta escena…">{{ $variant['text'] ?? '' }}</textarea>
</div>
