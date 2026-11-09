<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;

/** @extends Factory<User> */
class UserFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name' => 'SuperAdmin',
            'email' => fake()->unique()->safeEmail(),
            'password' => Hash::make('contrasena-de-prueba'),
        ];
    }
}
