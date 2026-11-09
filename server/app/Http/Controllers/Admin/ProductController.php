<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Product;
use App\Services\Catalog;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

class ProductController extends Controller
{
    public function index(): View
    {
        return view('admin.products.index', [
            'products' => Product::query()->orderBy('position')->orderBy('id')->get(),
        ]);
    }

    public function store(Request $request, Catalog $catalog): RedirectResponse
    {
        $data = $this->validated($request);
        $product = Product::query()->create($data + ['active' => true]);
        $catalog->bump();
        AuditLog::record('product.create', $product, $data);

        return back()->with('ok', 'Producto creado.');
    }

    public function update(Request $request, Product $product, Catalog $catalog): RedirectResponse
    {
        if ($request->has('toggle')) {
            $product->active = ! $product->active;
            $product->save();
            AuditLog::record('product.'.($product->active ? 'activate' : 'deactivate'), $product);
        } else {
            $data = $this->validated($request, $product);
            $product->fill($data)->save();
            AuditLog::record('product.update', $product, $data);
        }
        $catalog->bump();

        return back()->with('ok', 'Producto guardado.');
    }

    private function validated(Request $request, ?Product $product = null): array
    {
        $data = $request->validate([
            'product_id' => ['required', 'string', 'max:100', 'regex:/^[a-z0-9_.]+$/'],
            'platform' => ['required', Rule::in(Product::PLATFORMS)],
            'base_plan' => ['nullable', 'string', 'max:60', 'regex:/^[a-z0-9-]+$/'],
            'period' => ['required', Rule::in(Product::PERIODS)],
            'trial_days' => ['required', 'integer', 'min:0', 'max:90'],
            'position' => ['nullable', 'integer', 'min:0', 'max:1000'],
        ]);
        $data['position'] = (int) ($data['position'] ?? 0);
        $exists = Product::query()->where('product_id', $data['product_id'])->where('platform', $data['platform'])
            ->where('base_plan', $data['base_plan'] ?? null)
            ->when($product, fn ($q) => $q->whereKeyNot($product->id))->exists();
        if ($exists) {
            throw ValidationException::withMessages(['product_id' => 'Ya existe ese producto con ese plan.']);
        }

        return $data;
    }
}
