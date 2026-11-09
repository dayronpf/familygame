<?php

namespace App\Services\Apple;

use InvalidArgumentException;

/**
 * Utilidades ES256 (ECDSA P-256 + SHA-256) para JWT/JWS.
 *
 * openssl firma y verifica con la firma en DER (SEQUENCE { INTEGER r, INTEGER s }), pero JWS usa los 64 bytes R||S
 * en crudo (RFC 7518 §3.4). Aquí se convierte en los dos sentidos.
 */
final class Es256
{
    private const PART = 32;

    public static function b64url(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }

    public static function b64urlDecode(string $data): string|false
    {
        if ($data === '' || preg_match('/[^A-Za-z0-9_-]/', $data)) {
            return false;
        }

        return base64_decode(strtr($data, '-_', '+/').str_repeat('=', (4 - strlen($data) % 4) % 4), true);
    }

    /** Firma DER de openssl → R||S (64 bytes). */
    public static function derToRaw(string $der): string
    {
        $pos = 0;
        if (self::byte($der, $pos++) !== 0x30) {
            throw new InvalidArgumentException('La firma ECDSA no es una SEQUENCE DER.');
        }
        $len = self::length($der, $pos);
        if ($pos + $len !== strlen($der)) {
            throw new InvalidArgumentException('Longitud DER incorrecta.');
        }
        $r = self::integer($der, $pos);
        $s = self::integer($der, $pos);
        if ($pos !== strlen($der)) {
            throw new InvalidArgumentException('Sobran bytes en la firma DER.');
        }

        return self::pad($r).self::pad($s);
    }

    /** R||S (64 bytes) → firma DER para openssl_verify. */
    public static function rawToDer(string $raw): string
    {
        if (strlen($raw) !== 2 * self::PART) {
            throw new InvalidArgumentException('Una firma ES256 mide 64 bytes.');
        }
        $body = self::derInteger(substr($raw, 0, self::PART)).self::derInteger(substr($raw, self::PART));

        return "\x30".self::derLength(strlen($body)).$body;
    }

    private static function derInteger(string $bytes): string
    {
        $bytes = ltrim($bytes, "\x00");
        if ($bytes === '' || ord($bytes[0]) & 0x80) {
            $bytes = "\x00".$bytes; // positivo
        }

        return "\x02".self::derLength(strlen($bytes)).$bytes;
    }

    private static function derLength(int $len): string
    {
        return $len < 0x80 ? chr($len) : "\x81".chr($len);
    }

    private static function byte(string $der, int $pos): int
    {
        if (! isset($der[$pos])) {
            throw new InvalidArgumentException('Firma DER truncada.');
        }

        return ord($der[$pos]);
    }

    private static function length(string $der, int &$pos): int
    {
        $len = self::byte($der, $pos++);
        if ($len === 0x81) {
            $len = self::byte($der, $pos++);
        } elseif ($len > 0x80) {
            throw new InvalidArgumentException('Longitud DER no admitida.');
        }

        return $len;
    }

    private static function integer(string $der, int &$pos): string
    {
        if (self::byte($der, $pos++) !== 0x02) {
            throw new InvalidArgumentException('Se esperaba un INTEGER DER.');
        }
        $len = self::length($der, $pos);
        $value = substr($der, $pos, $len);
        if (strlen($value) !== $len) {
            throw new InvalidArgumentException('INTEGER DER truncado.');
        }
        $pos += $len;

        return $value;
    }

    private static function pad(string $int): string
    {
        $int = ltrim($int, "\x00");
        if (strlen($int) > self::PART) {
            throw new InvalidArgumentException('Componente de la firma demasiado largo para P-256.');
        }

        return str_pad($int, self::PART, "\x00", STR_PAD_LEFT);
    }
}
