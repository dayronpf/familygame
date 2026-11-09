<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\CodeRedemption;
use App\Models\Entitlement;
use App\Models\Pack;
use App\Models\Premise;
use App\Models\Purchase;
use App\Models\StoryRating;
use App\Services\Catalog;
use App\Services\EntitlementSigner;
use App\Services\GooglePlayClient;
use Illuminate\View\View;

class DashboardController extends Controller
{
    public function index(Catalog $catalog, EntitlementSigner $signer, GooglePlayClient $google): View
    {
        $now = now();
        $activeStore = Entitlement::query()->where('store_premium', true)->where('store_expires_at', '>', $now);

        return view('admin.dashboard', [
            'stats' => [
                'subscribers' => (clone $activeStore)->where('store_trial', false)->count(),
                'trials' => (clone $activeStore)->where('store_trial', true)->count(),
                'codeActive' => Entitlement::query()->where('code_expires_at', '>', $now)->count(),
                'purchases30' => Purchase::query()->where('created_at', '>=', $now->copy()->subDays(30))->count(),
                'redemptions' => CodeRedemption::query()->count(),
                'ratings' => StoryRating::query()->count(),
                'ratingAvg' => StoryRating::query()->avg('rating'),
                'pending' => Premise::query()->where('in_pack', true)->where('review_status', Premise::PENDING)->count(),
                'approved' => Premise::query()->where('in_pack', true)->where('review_status', Premise::APPROVED)->count(),
                'rejected' => Premise::query()->where('review_status', Premise::REJECTED)->count(),
            ],
            'catalog' => $catalog->build(),
            'packs' => Pack::query()->orderBy('id')->get(),
            'signerOk' => $signer->isConfigured(),
            'googleOk' => $google->isConfigured(),
            'rtdnOk' => (string) config('mininoches.google.rtdn_token') !== '',
        ]);
    }
}
