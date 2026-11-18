<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AuditController extends Controller
{
    public function index(Request $request): View
    {
        $tipo = (string) $request->query('tipo', '');
        $q = trim((string) $request->query('q', ''));
        $desde = $request->date('desde');
        $hasta = $request->date('hasta');
        $logs = AuditLog::query()->with('user')->latest('id')
            ->when($tipo !== '', fn ($w) => $w->where('action', 'like', $tipo.'%'))
            ->when($q !== '', fn ($w) => $w->where(fn ($x) => $x->where('details', 'like', "%{$q}%")->orWhere('subject_id', $q)))
            ->when($desde, fn ($w) => $w->where('created_at', '>=', $desde->startOfDay()))
            ->when($hasta, fn ($w) => $w->where('created_at', '<=', $hasta->endOfDay()));

        return view('admin.audit.index', [
            'logs' => $logs->paginate(50)->withQueryString(),
            'tipo' => $tipo,
            'q' => $q,
            'desde' => $desde?->format('Y-m-d'),
            'hasta' => $hasta?->format('Y-m-d'),
            'types' => ['story' => 'Cuentos', 'code' => 'Códigos', 'product' => 'Productos', 'packs' => 'Packs', 'log' => 'Sesiones'],
        ]);
    }
}
