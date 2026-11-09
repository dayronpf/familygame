<?php

namespace App\Services\Apple;

use RuntimeException;

/** Un JWS de Apple que no pasó la verificación (cadena, OID, fechas o firma). */
class AppleJwsException extends RuntimeException {}
