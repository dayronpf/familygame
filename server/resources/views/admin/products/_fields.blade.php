<label class="lg:col-span-2">Id del producto<br><input name="product_id" value="{{ $p?->product_id ?? 'mininoches_premium' }}" class="border rounded px-2 py-1 w-full font-mono" required></label>
<label>Tienda<br><select name="platform" class="border rounded px-2 py-1 w-full">
    @foreach (\App\Models\Product::PLATFORMS as $pl)<option value="{{ $pl }}" @selected(($p?->platform ?? 'android') === $pl)>{{ $pl }}</option>@endforeach
</select></label>
<label>Plan base<br><input name="base_plan" value="{{ $p?->base_plan }}" placeholder="anual" class="border rounded px-2 py-1 w-full font-mono"></label>
<label>Periodo<br><select name="period" class="border rounded px-2 py-1 w-full">
    @foreach (['P1Y' => 'Anual (P1Y)', 'P1M' => 'Mensual (P1M)'] as $v => $l)<option value="{{ $v }}" @selected(($p?->period ?? 'P1Y') === $v)>{{ $l }}</option>@endforeach
</select></label>
<label>Días de prueba<br><input type="number" name="trial_days" min="0" value="{{ $p?->trial_days ?? 7 }}" class="border rounded px-2 py-1 w-full"></label>
<label>Orden<br><input type="number" name="position" min="0" value="{{ $p?->position ?? 0 }}" class="border rounded px-2 py-1 w-full"></label>
