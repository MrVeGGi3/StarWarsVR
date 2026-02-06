shader_type spatial;

// Removemos a capacidade do objeto de receber sombra ou luz externa.
// Um laser é luz pura, ele não deve ter sombras.
render_mode unshaded, blend_add;

// --- PARÂMETROS QUE VOCÊ PODE EDITAR NO INSPECTOR ---

// A cor da borda (o halo do laser - vermelho, verde, azul...)
uniform vec3 glow_color : source_color = vec3(1.0, 0.1, 0.1); // Vermelho padrão

// A cor do núcleo (geralmente branco ou amarelo muito claro)
uniform vec3 core_color : source_color = vec3(1.0, 1.0, 1.0); // Branco padrão

// Quão "afiada" é a transição entre o núcleo e a borda.
// Valores mais altos deixam o núcleo branco menor e mais concentrado.
uniform float core_sharpness : hint_range(0.1, 10.0) = 3.0;

// A força total do brilho (para fazer o 'bloom' estourar)
uniform float emission_strength : hint_range(1.0, 20.0) = 5.0;


void fragment() {
    // --- CÁLCULO DO FRESNEL INVERTIDO ---
    // NORMAL: A direção para onde a superfície aponta.
    // VIEW: A direção da câmera para a superfície.
    // dot(NORMAL, VIEW): O produto escalar.
    // Resultado: 1.0 se olhando de frente (centro), indo para 0.0 nas bordas.
    float center_bias = dot(NORMAL, VIEW);

    // Aplicamos uma potência para controlar a nitidez do núcleo.
    // Se center_bias for 0.9, elevado a 3.0 vira 0.72 (reduz a área branca).
    center_bias = pow(max(center_bias, 0.0), core_sharpness);

    // --- MISTURA DE CORES (LERP/MIX) ---
    // A função mix(CorA, CorB, peso) mistura duas cores.
    // Se o peso (center_bias) for 0 (borda), usa glow_color.
    // Se o peso for 1 (centro), usa core_color.
    vec3 final_color = mix(glow_color, core_color, center_bias);

    // --- SAÍDA FINAL ---
    // ALBEDO é a cor base (embora em 'unshaded' importe menos).
    ALBEDO = final_color;

    // EMISSION é o que faz o objeto brilhar de verdade.
    // Multiplicamos pela força para ele ficar super brilhante.
    EMISSION = final_color * emission_strength;

    // Opcional: Deixa a borda levemente transparente para suavizar.
    // ALPHA = center_bias + 0.2; // (Se usar isso, remova 'blend_add' no topo)
}