<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Validator;

/**
 * Crea el único SuperAdmin del panel o le cambia la contraseña. No hay registro público ni segundo administrador.
 */
class AdminCommand extends Command
{
    protected $signature = 'mininoches:admin {email : Correo del SuperAdmin} {--password= : Contraseña (para scripts; si no, se pide)} {--name= : Nombre para mostrar}';

    protected $description = 'Crea el único SuperAdmin del panel o restablece su contraseña';

    public function handle(): int
    {
        $email = strtolower(trim((string) $this->argument('email')));
        if (Validator::make(['email' => $email], ['email' => 'required|email'])->fails()) {
            $this->error('El correo no es válido.');

            return self::FAILURE;
        }

        $existing = User::query()->first();
        if ($existing && $existing->email !== $email) {
            $this->error("Ya existe un SuperAdmin ({$existing->email}). Solo puede haber uno: use ese correo para restablecer su contraseña.");

            return self::FAILURE;
        }

        $password = $this->option('password');
        if ($password === null) {
            $password = (string) $this->secret('Contraseña (mínimo 12 caracteres)');
            if ($password !== (string) $this->secret('Repita la contraseña')) {
                $this->error('Las contraseñas no coinciden.');

                return self::FAILURE;
            }
        }
        if (mb_strlen($password) < 12) {
            $this->error('La contraseña debe tener al menos 12 caracteres.');

            return self::FAILURE;
        }

        if ($existing) {
            $existing->forceFill(['password' => $password, 'remember_token' => null])->save();
            $this->info("Contraseña del SuperAdmin {$email} restablecida.");
        } else {
            User::query()->create([
                'name' => $this->option('name') ?: 'SuperAdmin',
                'email' => $email,
                'password' => $password,
            ]);
            $this->info("SuperAdmin {$email} creado. Entre en /admin.");
        }

        return self::SUCCESS;
    }
}
