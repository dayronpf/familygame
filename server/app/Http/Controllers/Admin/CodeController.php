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
    public function index(): View
    {
        return view('admin.codes.index', [
            'codes' => RedeemCode::query()->latest('id')->paginate(50),
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
