<?php

namespace App\Http\Controllers\Api;

use App\Services\Catalog;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class CatalogController extends ApiController
{
    public function show(Request $request, Catalog $catalog): Response
    {
        $body = json_encode($catalog->build(), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        $etag = '"'.sha1($body).'"';
        $headers = ['ETag' => $etag, 'Cache-Control' => 'public, max-age=300'];

        $ifNoneMatch = array_map('trim', explode(',', (string) $request->header('If-None-Match')));
        if (in_array($etag, $ifNoneMatch, true) || in_array('W/'.$etag, $ifNoneMatch, true)) {
            return response('', 304, $headers);
        }

        return response($body, 200, $headers + ['Content-Type' => 'application/json']);
    }
}
