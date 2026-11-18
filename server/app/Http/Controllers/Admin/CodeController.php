<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\RedeemCode;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class CodeController extends Controller
{
    public function index(Request $request): View
    {
        $q = trim((string) $request->query('q', ''));
        $estado = (string) $request->query('estado', '');
        $perPage = in_array((int) $request->query('por_pagina'), [25, 50, 100], true) ? (int) $request->query('por_pagina') : 25;
        $codes = RedeemCode::query()->latest('id')
            ->when($q !== '', fn ($w) => $w->where(fn ($x) => $x->where('code', 'like', '%'.strtoupper($q).'%')->orWhere('note', 'like', "%{$q}%")))
            ->when($estado === 'activos', fn ($w) => $w->where('active', true)->whereColumn('uses_count', '<', 'max_uses')
                ->where(fn ($x) => $x->whereNull('expires_at')->orWhere('expires_at', '>', now())))
            ->when($estado === 'agotados', fn ($w) => $w->whereColumn('uses_count', '>=', 'max_uses'))
            ->when($estado === 'caducados', fn ($w) => $w->where('expires_at', '<=', now()))
            ->when($estado === 'desactivados', fn ($w) => $w->where('active', false));

        return view('admin.codes.index', [
            'codes' => $codes->paginate($perPage)->withQueryString(),
            'q' => $q,
            'estado' => $estado,
            'perPage' => $perPage,
            'totals' => [
                'all' => RedeemCode::query()->count(),
                'redeemed' => RedeemCode::query()->sum('uses_count'),
            ],
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        if ($request->filled('code')) {
            $request->merge(['code' => RedeemCode::normalize($request->input('code'))]);
        }
        $data = $request->validate([
            'code' => ['nullable', 'string', 'regex:/^[A-Z0-9-]{4,32}$/', Rule::unique('redeem_codes', 'code')],
            'days' => ['required', 'integer', 'min:1', 'max:3650'],
            'max_uses' => ['required', 'integer', 'min:1', 'max:100000'],
            'expires_at' => ['nullable', 'date', 'after:today'],
            'note' => ['nullable', 'string', 'max:255'],
            'quantity' => ['nullable', 'integer', 'min:1', 'max:500'],
        ], [
            'code.regex' => 'El código solo puede tener letras A-Z, números y guiones (4 a 32).',
            'code.unique' => 'Ese código ya existe.',
        ]);

        $quantity = ! empty($data['code']) ? 1 : (int) ($data['quantity'] ?? 1);
        $created = [];
        for ($i = 0; $i < $quantity; $i++) {
            $code = RedeemCode::query()->create([
                'code' => $data['code'] ?? RedeemCode::generate(),
                'days' => $data['days'],
                'max_uses' => $data['max_uses'],
                'expires_at' => $data['expires_at'] ?? null,
                'note' => $data['note'] ?? null,
                'active' => true,
            ]);
            $created[] = $code->code;
        }
        AuditLog::record('code.create', null, [
            'codes' => $created, 'days' => $data['days'], 'max_uses' => $data['max_uses'],
        ]);

        return back()->with('ok', 'Códigos creados: '.implode(', ', $created));
    }

    public function toggle(RedeemCode $code): RedirectResponse
    {
        $code->active = ! $code->active;
        $code->save();
        AuditLog::record($code->active ? 'code.activate' : 'code.deactivate', $code, ['code' => $code->code]);

        return back()->with('ok', $code->active ? "{$code->code} activado." : "{$code->code} desactivado.");
    }
}
