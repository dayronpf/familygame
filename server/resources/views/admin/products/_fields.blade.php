<x-field label="Id del producto" name="product_id" hint="Igual que en Play Console / App Store Connect.">
    <input name="product_id" value="{{ $p?->product_id ?? 'mininoches_premium' }}" class="input font-mono" required>
</x-field>
<x-field label="Tienda" name="platform">
    <select name="platform" class="input">
        @foreach (\App\Models\Product::PLATFORMS as $pl)<option value="{{ $pl }}" @selected(($p?->platform ?? 'android') === $pl)>{{ $pl === 'ios' ? 'App Store' : 'Google Play' }}</option>@endforeach
    </select>
</x-field>
<x-field label="Plan base" name="base_plan" hint="Solo Google Play: anual, mensual…">
    <input name="base_plan" value="{{ $p?->base_plan }}" placeholder="anual" class="input font-mono">
</x-field>
<x-field label="Periodo" name="period">
    <select name="period" class="input">
        @foreach (['P1Y' => 'Anual', 'P1M' => 'Mensual'] as $v => $l)<option value="{{ $v }}" @selected(($p?->period ?? 'P1Y') === $v)>{{ $l }}</option>@endforeach
    </select>
</x-field>
<x-field label="Días de prueba gratis" name="trial_days">
    <input type="number" name="trial_days" min="0" max="90" value="{{ $p?->trial_days ?? 7 }}" class="input">
</x-field>
<x-field label="Orden en la app" name="position" hint="El menor sale primero.">
    <input type="number" name="position" min="0" value="{{ $p?->position ?? 0 }}" class="input">
</x-field>
