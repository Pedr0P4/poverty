@tool
class_name GeradorTerreno
extends Node3D


@export_group("Geração Infinita e Chunks")
@export var tamanho_chunk: int = 32
@export_range(0.2, 5.0, 0.1) var resolucao_vertice: float = 1.0
@export_range(2, 12, 1) var distancia_visao_chunks: int = 5
@export_range(60.0, 180.0, 5.0) var angulo_visao_graus: float = 145.0
@export_range(1, 4, 1) var raio_seguranca_chunks: int = 2
@export_range(0.5, 10.0, 0.5) var tempo_descarregar_segundos: float = 3.5
@export_range(1, 8, 1) var max_chunks_por_frame: int = 2
@export var descarregar_chunks_atras: bool = true
@export var gerar_no_ready: bool = true
@export var regenerar_terreno: bool = false:
	set(valor):
		if valor and is_inside_tree():
			regenerar_tudo()

@export_group("Névoa (Fog)")
@export var ativar_nevoa: bool = true
@export var cor_nevoa: Color = Color(0.72, 0.82, 0.92, 1.0)
@export var ajustar_nevoa_automaticamente: bool = true
@export_range(10.0, 300.0, 5.0) var distancia_nevoa_inicio: float = 65.0
@export_range(20.0, 500.0, 5.0) var distancia_nevoa_fim: float = 130.0

@export_group("Topografia e Elevação")
@export_range(5.0, 100.0, 1.0) var altura_maxima_montanhas: float = 30.0
@export_range(1.0, 30.0, 0.5) var profundidade_maxima_agua: float = 6.0
@export_range(0.0, 3.0, 0.1) var altura_maxima_planicie: float = 1.0
@export_range(0.1, 0.8, 0.01) var limiar_montanhas: float = 0.45
@export_range(1.5, 6.0, 0.1) var expoente_montanhas: float = 3.0

@export_group("Ruído da Topografia (FastNoiseLite)")
@export var seed_terreno: int = 1337:
	set(valor):
		seed_terreno = valor
		_inicializar_ruidos()
@export_range(0.001, 0.05, 0.001) var frequencia_terreno: float = 0.008:
	set(valor):
		frequencia_terreno = valor
		_inicializar_ruidos()
@export_range(1, 8, 1) var oitavas_terreno: int = 4:
	set(valor):
		oitavas_terreno = valor
		_inicializar_ruidos()

@export_group("Sistema de Cores (Vertex Colors)")
@export var cor_areia: Color = Color(0.95, 0.85, 0.45)
@export var cor_grama: Color = Color(0.35, 0.65, 0.25)
@export var cor_rocha: Color = Color(0.45, 0.45, 0.45)
@export var cor_neve: Color = Color(0.95, 0.95, 0.95)
@export_range(1.0, 20.0, 0.5) var altura_inicio_rocha: float = 3.5
@export_range(10.0, 80.0, 1.0) var altura_inicio_neve: float = 18.0

@export_group("Civilização e Vilarejos")
@export var cena_casa: PackedScene
@export var seed_civilizacao: int = 9999:
	set(valor):
		seed_civilizacao = valor
		_inicializar_ruidos()
@export_range(0.002, 0.08, 0.002) var frequencia_civilizacao: float = 0.015:
	set(valor):
		frequencia_civilizacao = valor
		_inicializar_ruidos()
@export_range(0.1, 0.7, 0.02) var limiar_zona_vila: float = 0.35
@export_range(4.0, 25.0, 0.5) var espacamento_grade_casas: float = 8.5
@export_range(0.0, 5.0, 0.2) var jitter_casas: float = 2.8
@export_range(0.05, 1.5, 0.05) var inclinacao_maxima_casa: float = 0.35
@export_range(0.2, 1.0, 0.05) var densidade_casas_na_vila: float = 0.85

@export_group("Inimigos Procedurais")
@export var cena_inimigo: PackedScene = preload("res://scene/enemy.tscn")
@export var gerar_inimigos: bool = true
@export var seed_inimigos_offset: int = 4242
@export_range(0.0, 1.0, 0.05) var chance_inimigo_vila: float = 0.55
@export_range(1, 6, 1) var max_inimigos_por_chunk_vila: int = 3
@export_range(0.0, 1.0, 0.05) var chance_inimigo_planicie: float = 0.25
@export_range(5.0, 40.0, 1.0) var distancia_segura_spawn_player: float = 16.0

@export_group("Baús de Sobrevivência")
@export var gerar_baus: bool = true
@export var seed_baus_offset: int = 8484
@export_range(0.0, 1.0, 0.05) var chance_bau_vila: float = 0.58
@export_range(1, 4, 1) var max_baus_por_chunk_vila: int = 2
@export_range(0.0, 1.0, 0.05) var chance_bau_planicie: float = 0.16

@export_group("Dificuldade e Ondas (Estilo Vampire Survivors)")
@export var escalar_dificuldade_tempo: bool = true
@export_range(10.0, 90.0, 2.0) var intervalo_inicial_ondas: float = 26.0
@export_range(6.0, 30.0, 1.0) var intervalo_minimo_ondas: float = 10.0
@export_range(8, 60, 2) var max_inimigos_vivos_simultaneos: int = 28

@export_group("Ciclo de Dia e Noite")
@export var ativar_ciclo_dia_noite: bool = true
@export_range(60.0, 900.0, 10.0) var duracao_ciclo_dia_noite: float = 210.0
@export_range(0.0, 1.0, 0.01) var hora_inicial_ciclo: float = 0.30

@export_group("Ajuste de Jogador (Anti-Queda)")
@export var posicionar_player_no_chao: bool = true
@export var player: CharacterBody3D

var noise_terreno: FastNoiseLite
var noise_civilizacao: FastNoiseLite

var _chunks_container: Node3D
var _inimigos_container: Node3D
var _material_terreno: StandardMaterial3D
var _material_base_casa: StandardMaterial3D
var _material_telhado_casa: StandardMaterial3D

var _camera: Camera3D
var _environment_ref: Environment
var _directional_light_ref: DirectionalLight3D

var _chunks_ativos: Dictionary = {}
var _timers_descarregamento: Dictionary = {}
var _fila_geracao: Array[Vector2i] = []
var _na_fila: Dictionary = {}

var _registro_inimigos: Dictionary = {}
var _chunks_inimigos_gerados: Dictionary = {}
var _registro_baus: Dictionary = {}
var _chunks_baus_gerados: Dictionary = {}
var _pos_inicial_player_xz: Vector2 = Vector2.ZERO

static var instance: GeradorTerreno = null

static func get_instance() -> GeradorTerreno:
	return instance

var _tempo_sobrevivencia: float = 0.0
var _timer_proxima_onda: float = 24.0
var _contador_ondas: int = 0
var _inimigos_eliminados: int = 0
var _fase_dia: float = 0.30

var _ultima_pos_jogador_xz: Vector2 = Vector2(INF, INF)
var _ultima_dir_visao: Vector2 = Vector2.ZERO
var _player_posicionado: bool = false


func _ready() -> void:
	instance = self
	_inicializar_ruidos()
	_inicializar_materiais()
	_preparar_chunks_container()
	
	if Engine.is_editor_hint():
		if gerar_no_ready:
			_gerar_preview_editor()
		return
	
	_tempo_sobrevivencia = 0.0
	_timer_proxima_onda = intervalo_inicial_ondas
	_contador_ondas = 0
	_inimigos_eliminados = 0
	_fase_dia = hora_inicial_ciclo
	Enemy.is_night_time = false


func _exit_tree() -> void:
	if instance == self:
		instance = null

	
	if get_world_3d() != null:
		NavigationServer3D.map_set_edge_connection_margin(get_world_3d().get_navigation_map(), 2.0)
	
	if ativar_nevoa:
		_configurar_nevoa()
	
	_localizar_luz_e_ambiente()
	if ativar_ciclo_dia_noite:
		_atualizar_ciclo_dia_noite(0.0)
	
	var target_player := _obter_player()
	var pos_jogador_xz := Vector2.ZERO
	if target_player != null:
		pos_jogador_xz = Vector2(target_player.global_position.x, target_player.global_position.z)
	_pos_inicial_player_xz = pos_jogador_xz
	
	var chunk_size_m: float = float(tamanho_chunk) * resolucao_vertice
	var p_cx: int = int(floor(pos_jogador_xz.x / chunk_size_m))
	var p_cz: int = int(floor(pos_jogador_xz.y / chunk_size_m))
	
	for dx in range(-raio_seguranca_chunks, raio_seguranca_chunks + 1):
		for dz in range(-raio_seguranca_chunks, raio_seguranca_chunks + 1):
			var coord := Vector2i(p_cx + dx, p_cz + dz)
			_gerar_chunk(coord)
	
	if posicionar_player_no_chao and target_player != null:
		_garantir_player_no_chao()
	
	var dir_visao := _obter_direcao_visao(target_player) if target_player != null else Vector2(0.0, -1.0)
	_ultima_pos_jogador_xz = pos_jogador_xz
	_ultima_dir_visao = dir_visao
	_atualizar_visibilidade_chunks(pos_jogador_xz, dir_visao)
	_atualizar_estado_inimigos(pos_jogador_xz)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	_processar_timers_descarregamento(delta)
	
	var target_player := _obter_player()
	if target_player == null:
		return
	
	var player_typed := target_player as Player
	if player_typed == null or not player_typed.is_dead:
		_tempo_sobrevivencia += delta
	
	if ativar_ciclo_dia_noite:
		_atualizar_ciclo_dia_noite(delta)
	
	var nivel_ameaca := _obter_nivel_ameaca()
	var dia_num := 1 + int(floor(_tempo_sobrevivencia / maxf(15.0, duracao_ciclo_dia_noite)))
	if player_typed != null and player_typed.inventory_ui != null:
		player_typed.inventory_ui.update_survival_timer_hud(_tempo_sobrevivencia, Enemy.is_night_time, _fase_dia, nivel_ameaca, dia_num)
	
	var pos_jogador_xz := Vector2(target_player.global_position.x, target_player.global_position.z)
	var dir_visao := _obter_direcao_visao(target_player)
	
	var deslocou: bool = pos_jogador_xz.distance_squared_to(_ultima_pos_jogador_xz) > 1.5
	var girou: bool = dir_visao.dot(_ultima_dir_visao) < 0.996
	
	if deslocou or girou or not _fila_geracao.is_empty():
		_ultima_pos_jogador_xz = pos_jogador_xz
		_ultima_dir_visao = dir_visao
		_atualizar_visibilidade_chunks(pos_jogador_xz, dir_visao)
	
	_processar_fila_geracao()
	if escalar_dificuldade_tempo and (player_typed == null or not player_typed.is_dead):
		_processar_ondas_inimigos(delta, pos_jogador_xz)
	_atualizar_estado_inimigos(pos_jogador_xz)
	


func _processar_timers_descarregamento(delta: float) -> void:
	if _timers_descarregamento.is_empty():
		return
	
	var coords := _timers_descarregamento.keys()
	for coord in coords:
		var tempo: float = _timers_descarregamento[coord] - delta
		if tempo <= 0.0:
			_timers_descarregamento.erase(coord)
			_descarregar_chunk(coord)
		else:
			_timers_descarregamento[coord] = tempo


func _inicializar_ruidos() -> void:
	if noise_terreno == null:
		noise_terreno = FastNoiseLite.new()
	noise_terreno.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_terreno.seed = seed_terreno
	noise_terreno.frequency = frequencia_terreno
	noise_terreno.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_terreno.fractal_octaves = oitavas_terreno
	noise_terreno.fractal_lacunarity = 2.0
	noise_terreno.fractal_gain = 0.5

	if noise_civilizacao == null:
		noise_civilizacao = FastNoiseLite.new()
	noise_civilizacao.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_civilizacao.seed = seed_civilizacao
	noise_civilizacao.frequency = frequencia_civilizacao
	noise_civilizacao.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_civilizacao.fractal_octaves = 2


func _inicializar_materiais() -> void:
	if _material_terreno == null:
		_material_terreno = StandardMaterial3D.new()
		_material_terreno.vertex_color_use_as_albedo = true
		_material_terreno.roughness = 0.95
		_material_terreno.metallic_specular = 0.1
		_material_terreno.cull_mode = BaseMaterial3D.CULL_BACK
	
	if _material_base_casa == null:
		_material_base_casa = StandardMaterial3D.new()
		_material_base_casa.albedo_color = Color(0.85, 0.78, 0.68)
		_material_base_casa.roughness = 0.85
	
	if _material_telhado_casa == null:
		_material_telhado_casa = StandardMaterial3D.new()
		_material_telhado_casa.albedo_color = Color(0.72, 0.26, 0.16)
		_material_telhado_casa.roughness = 0.65


func _preparar_chunks_container() -> void:
	for filho in get_children():
		if filho.name != "Chunks" and filho.name != "Inimigos":
			filho.queue_free()
	
	if _chunks_container == null or not is_instance_valid(_chunks_container):
		_chunks_container = get_node_or_null("Chunks") as Node3D
		if _chunks_container == null:
			_chunks_container = Node3D.new()
			_chunks_container.name = "Chunks"
			add_child(_chunks_container)
	
	for c in _chunks_container.get_children():
		c.queue_free()
	
	if _inimigos_container == null or not is_instance_valid(_inimigos_container):
		_inimigos_container = get_node_or_null("Inimigos") as Node3D
		if _inimigos_container == null:
			_inimigos_container = Node3D.new()
			_inimigos_container.name = "Inimigos"
			add_child(_inimigos_container)
	
	for e in _inimigos_container.get_children():
		e.queue_free()
	
	_chunks_ativos.clear()
	_timers_descarregamento.clear()
	_fila_geracao.clear()
	_na_fila.clear()
	_registro_inimigos.clear()
	_chunks_inimigos_gerados.clear()
	_registro_baus.clear()
	_chunks_baus_gerados.clear()


func _configurar_nevoa() -> void:
	if not ativar_nevoa:
		return
	
	var env: Environment = null
	var world_env: WorldEnvironment = null
	
	if get_parent() != null:
		world_env = get_parent().find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env == null and is_inside_tree() and get_tree() != null and get_tree().root != null:
		world_env = get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	
	if world_env != null:
		if world_env.environment == null:
			world_env.environment = Environment.new()
		env = world_env.environment
	elif get_viewport() != null and get_viewport().world_3d != null:
		env = get_viewport().world_3d.environment
	
	if env == null:
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment_Nevoa"
		env = Environment.new()
		world_env.environment = env
		if get_parent() != null:
			get_parent().add_child(world_env)
		else:
			add_child(world_env)
	
	_environment_ref = env
	
	if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
		cor_nevoa = sky_mat.sky_horizon_color
	
	var chunk_size_m: float = float(tamanho_chunk) * resolucao_vertice
	var alcance_maximo_m: float = float(distancia_visao_chunks) * chunk_size_m
	
	var dist_fim: float = distancia_nevoa_fim
	var dist_ini: float = distancia_nevoa_inicio
	
	if ajustar_nevoa_automaticamente:
		dist_fim = alcance_maximo_m * 0.80
		dist_ini = maxf(35.0, (float(raio_seguranca_chunks) + 0.1) * chunk_size_m)
		distancia_nevoa_fim = dist_fim
		distancia_nevoa_inicio = dist_ini
	
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = cor_nevoa
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.15
	env.fog_depth_begin = dist_ini
	env.fog_depth_end = dist_fim
	env.fog_depth_curve = 1.0


func _localizar_luz_e_ambiente() -> void:
	if _environment_ref == null:
		var world_env: WorldEnvironment = null
		if get_parent() != null:
			world_env = get_parent().find_child("WorldEnvironment", true, false) as WorldEnvironment
		if world_env == null and is_inside_tree() and get_tree() != null and get_tree().root != null:
			world_env = get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
		if world_env != null:
			_environment_ref = world_env.environment
	
	if _directional_light_ref == null or not is_instance_valid(_directional_light_ref):
		if get_parent() != null:
			_directional_light_ref = get_parent().find_child("DirectionalLight3D", true, false) as DirectionalLight3D
		if _directional_light_ref == null and is_inside_tree() and get_tree() != null and get_tree().root != null:
			_directional_light_ref = get_tree().root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D


func _atualizar_ciclo_dia_noite(delta: float) -> void:
	var duracao := maxf(15.0, duracao_ciclo_dia_noite)
	_fase_dia = fposmod(_fase_dia + (delta / duracao), 1.0)
	
	# angulo_sol = 0 no nascer (06:00 -> _fase_dia = 0.25), PI/2 ao meio-dia (0.50), PI no pôr (0.75)
	var angulo_sol: float = (_fase_dia - 0.25) * TAU
	var elevacao_sol: float = sin(angulo_sol) # -1 meia-noite .. +1 meio-dia
	
	Enemy.is_night_time = elevacao_sol < -0.05
	
	if _directional_light_ref == null or not is_instance_valid(_directional_light_ref):
		_localizar_luz_e_ambiente()
	
	# Paletas de cores para Dia, Crepúsculo (Amanhecer/Entardecer) e Noite
	var sky_top_day := Color(0.36, 0.64, 0.95, 1.0)
	var sky_hor_day := Color(0.72, 0.82, 0.92, 1.0)
	var gnd_bot_day := Color(0.20, 0.17, 0.13, 1.0)
	var amb_day := Color(0.68, 0.69, 0.72, 1.0)
	var light_day := Color(1.0, 0.97, 0.92, 1.0)
	
	var sky_top_dusk := Color(0.28, 0.26, 0.52, 1.0)
	var sky_hor_dusk := Color(0.92, 0.50, 0.28, 1.0)
	var gnd_bot_dusk := Color(0.14, 0.11, 0.10, 1.0)
	var amb_dusk := Color(0.48, 0.36, 0.34, 1.0)
	var light_dusk := Color(1.0, 0.62, 0.34, 1.0)
	
	var sky_top_night := Color(0.03, 0.05, 0.11, 1.0)
	var sky_hor_night := Color(0.07, 0.10, 0.18, 1.0)
	var gnd_bot_night := Color(0.03, 0.04, 0.06, 1.0)
	var amb_night := Color(0.14, 0.18, 0.28, 1.0)
	var light_night := Color(0.38, 0.50, 0.78, 1.0)
	
	var sky_top: Color
	var sky_hor: Color
	var gnd_bot: Color
	var amb_col: Color
	var light_col: Color
	var light_energy: float
	var amb_energy: float
	
	if elevacao_sol >= 0.25:
		var t := clampf((elevacao_sol - 0.25) / 0.75, 0.0, 1.0)
		sky_top = sky_top_dusk.lerp(sky_top_day, t)
		sky_hor = sky_hor_dusk.lerp(sky_hor_day, t)
		gnd_bot = gnd_bot_dusk.lerp(gnd_bot_day, t)
		amb_col = amb_dusk.lerp(amb_day, t)
		light_col = light_dusk.lerp(light_day, t)
		light_energy = lerpf(0.72, 1.12, t)
		amb_energy = lerpf(0.65, 1.0, t)
	elif elevacao_sol >= -0.22:
		var t := clampf((elevacao_sol + 0.22) / 0.47, 0.0, 1.0)
		sky_top = sky_top_night.lerp(sky_top_dusk, t)
		sky_hor = sky_hor_night.lerp(sky_hor_dusk, t)
		gnd_bot = gnd_bot_night.lerp(gnd_bot_dusk, t)
		amb_col = amb_night.lerp(amb_dusk, t)
		light_col = light_night.lerp(light_dusk, t)
		light_energy = lerpf(0.20, 0.72, t)
		amb_energy = lerpf(0.32, 0.65, t)
	else:
		sky_top = sky_top_night
		sky_hor = sky_hor_night
		gnd_bot = gnd_bot_night
		amb_col = amb_night
		light_col = light_night
		light_energy = 0.20
		amb_energy = 0.32
	
	if _directional_light_ref != null and is_instance_valid(_directional_light_ref):
		# Quando é noite, mantém a luz vindo de cima como luar suave para não iluminar por baixo do terreno
		var pitch_deg: float
		if elevacao_sol >= 0.0:
			pitch_deg = -lerpf(12.0, 68.0, elevacao_sol)
		else:
			pitch_deg = -lerpf(15.0, 48.0, absf(elevacao_sol))
		var yaw_deg: float = (_fase_dia * 360.0) - 90.0
		_directional_light_ref.rotation_degrees = Vector3(pitch_deg, yaw_deg, 0.0)
		_directional_light_ref.light_color = light_col
		_directional_light_ref.light_energy = light_energy
	
	if _environment_ref != null:
		if _environment_ref.sky != null and _environment_ref.sky.sky_material is ProceduralSkyMaterial:
			var sky_mat := _environment_ref.sky.sky_material as ProceduralSkyMaterial
			sky_mat.sky_top_color = sky_top
			sky_mat.sky_horizon_color = sky_hor
			sky_mat.ground_horizon_color = sky_hor
			sky_mat.ground_bottom_color = gnd_bot
		_environment_ref.ambient_light_color = amb_col
		_environment_ref.ambient_light_energy = amb_energy
		if _environment_ref.fog_enabled:
			_environment_ref.fog_light_color = sky_hor
			_environment_ref.fog_light_energy = lerpf(0.38, 1.0, clampf((elevacao_sol + 0.3) / 1.3, 0.0, 1.0))


func obter_chunk_da_posicao(pos_xz: Vector2) -> Vector2i:
	var chunk_size_m: float = float(tamanho_chunk) * resolucao_vertice
	return Vector2i(int(floor(pos_xz.x / chunk_size_m)), int(floor(pos_xz.y / chunk_size_m)))


func is_posicao_em_chunk_ativo(pos: Vector3) -> bool:
	var coord := obter_chunk_da_posicao(Vector2(pos.x, pos.z))
	return _chunks_ativos.has(coord)


func _obter_chunks_com_inimigos_em_acao(pos_jogador_xz: Vector2, dist_despawn_m: float) -> Dictionary:
	var chunks_acao: Dictionary = {}
	for enemy_id in _registro_inimigos.keys():
		var dados: Dictionary = _registro_inimigos[enemy_id]
		if dados["dead"]:
			continue
		var inst: Enemy = dados["instancia"] as Enemy if is_instance_valid(dados["instancia"]) else null
		if inst != null and not inst.is_dead and (inst.detected or inst.alert):
			var pos_xz := Vector2(inst.global_position.x, inst.global_position.z)
			var dist := pos_jogador_xz.distance_to(pos_xz)
			if dist <= dist_despawn_m:
				var coord := obter_chunk_da_posicao(pos_xz)
				chunks_acao[coord] = dist
	return chunks_acao


func _atualizar_visibilidade_chunks(pos_jogador_xz: Vector2, dir_visao: Vector2) -> void:
	var chunk_size_m: float = float(tamanho_chunk) * resolucao_vertice
	var p_cx: int = int(floor(pos_jogador_xz.x / chunk_size_m))
	var p_cz: int = int(floor(pos_jogador_xz.y / chunk_size_m))
	
	var cos_load_cone: float = cos(deg_to_rad(angulo_visao_graus * 0.5))
	var cos_despawn_cone: float = cos(deg_to_rad(minf(180.0, angulo_visao_graus + 35.0) * 0.5))
	
	var dist_max_m: float = float(distancia_visao_chunks) * chunk_size_m
	var dist_despawn_m: float = (float(distancia_visao_chunks) + 0.8) * chunk_size_m
	var raio_seguranca_m: float = (float(raio_seguranca_chunks) + 0.5) * chunk_size_m
	
	var chunks_desejados: Dictionary = {}
	var chunks_inimigos_acao := _obter_chunks_com_inimigos_em_acao(pos_jogador_xz, dist_despawn_m)
	
	for dx in range(-distancia_visao_chunks, distancia_visao_chunks + 1):
		for dz in range(-distancia_visao_chunks, distancia_visao_chunks + 1):
			var coord := Vector2i(p_cx + dx, p_cz + dz)
			var centro_chunk := Vector2(
				(float(coord.x) + 0.5) * chunk_size_m,
				(float(coord.y) + 0.5) * chunk_size_m
			)
			var to_chunk := centro_chunk - pos_jogador_xz
			var dist := to_chunk.length()
			
			if dist <= raio_seguranca_m:
				chunks_desejados[coord] = dist
				continue
			
			if chunks_inimigos_acao.has(coord):
				chunks_desejados[coord] = dist
				continue
			
			if dist <= dist_max_m:
				var dir_chunk := to_chunk / dist
				var dot := dir_visao.dot(dir_chunk)
				if dot >= cos_load_cone:
					chunks_desejados[coord] = dist
	
	for coord_acao in chunks_inimigos_acao.keys():
		if not chunks_desejados.has(coord_acao):
			chunks_desejados[coord_acao] = chunks_inimigos_acao[coord_acao]
	
	for coord in chunks_desejados.keys():
		if _timers_descarregamento.has(coord):
			_timers_descarregamento.erase(coord)
	
	if descarregar_chunks_atras:
		var coords_ativas := _chunks_ativos.keys()
		for coord in coords_ativas:
			var centro_chunk := Vector2(
				(float(coord.x) + 0.5) * chunk_size_m,
				(float(coord.y) + 0.5) * chunk_size_m
			)
			var to_chunk := centro_chunk - pos_jogador_xz
			var dist := to_chunk.length()
			
			if dist <= raio_seguranca_m or chunks_inimigos_acao.has(coord):
				if _timers_descarregamento.has(coord):
					_timers_descarregamento.erase(coord)
				continue
			
			var fora_da_visao: bool = false
			
			if dist > dist_despawn_m:
				fora_da_visao = true
			else:
				var dir_chunk := to_chunk / dist
				var dot := dir_visao.dot(dir_chunk)
				if dot < cos_despawn_cone:
					fora_da_visao = true
			
			if fora_da_visao:
				if not _timers_descarregamento.has(coord):
					_timers_descarregamento[coord] = tempo_descarregar_segundos
			else:
				if _timers_descarregamento.has(coord):
					_timers_descarregamento.erase(coord)
	
	for coord in chunks_desejados.keys():
		if not _chunks_ativos.has(coord) and not _na_fila.has(coord):
			_fila_geracao.append(coord)
			_na_fila[coord] = true
	
	var i := _fila_geracao.size() - 1
	while i >= 0:
		var coord: Vector2i = _fila_geracao[i]
		if not chunks_desejados.has(coord):
			_na_fila.erase(coord)
			_fila_geracao.remove_at(i)
		i -= 1
	
	_fila_geracao.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var c_a := Vector2((float(a.x) + 0.5) * chunk_size_m, (float(a.y) + 0.5) * chunk_size_m)
		var c_b := Vector2((float(b.x) + 0.5) * chunk_size_m, (float(b.y) + 0.5) * chunk_size_m)
		return pos_jogador_xz.distance_squared_to(c_a) < pos_jogador_xz.distance_squared_to(c_b)
	)


func _processar_fila_geracao() -> void:
	var gerados: int = 0
	while not _fila_geracao.is_empty() and gerados < max_chunks_por_frame:
		var coord: Vector2i = _fila_geracao.pop_front()
		_na_fila.erase(coord)
		
		if _chunks_ativos.has(coord):
			continue
		
		_gerar_chunk(coord)
		gerados += 1


func _gerar_chunk(coord: Vector2i) -> Node3D:
	if _chunks_ativos.has(coord):
		return _chunks_ativos[coord]
	
	if _chunks_container == null or not is_instance_valid(_chunks_container):
		_preparar_chunks_container()
	
	var chunk_size_m: float = float(tamanho_chunk) * resolucao_vertice
	var x_start: float = float(coord.x) * chunk_size_m
	var z_start: float = float(coord.y) * chunk_size_m
	
	var chunk_node := Node3D.new()
	chunk_node.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk_node.position = Vector3(x_start, 0.0, z_start)
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for iz in range(tamanho_chunk + 1):
		var lz: float = float(iz) * resolucao_vertice
		var wz: float = z_start + lz
		var v_ratio: float = float(iz) / float(tamanho_chunk)
		
		for ix in range(tamanho_chunk + 1):
			var lx: float = float(ix) * resolucao_vertice
			var wx: float = x_start + lx
			var u_ratio: float = float(ix) / float(tamanho_chunk)
			
			var wy: float = obter_altura(wx, wz)
			var cor_vert: Color = obter_cor_vertice(wy)
			
			st.set_color(cor_vert)
			st.set_uv(Vector2(u_ratio, v_ratio))
			st.add_vertex(Vector3(lx, wy, lz))
	
	var largura_linha: int = tamanho_chunk + 1
	for iz in range(tamanho_chunk):
		for ix in range(tamanho_chunk):
			var i00: int = (iz * largura_linha) + ix
			var i10: int = (iz * largura_linha) + (ix + 1)
			var i01: int = ((iz + 1) * largura_linha) + ix
			var i11: int = ((iz + 1) * largura_linha) + (ix + 1)
			
			st.add_index(i00)
			st.add_index(i10)
			st.add_index(i01)
			
			st.add_index(i10)
			st.add_index(i11)
			st.add_index(i01)
	
	st.generate_normals()
	st.generate_tangents()
	var malha_chunk: ArrayMesh = st.commit()
	
	var nav_region := NavigationRegion3D.new()
	var navmesh := NavigationMesh.new()
	navmesh.agent_height = 2.0
	navmesh.agent_radius = 0.55
	navmesh.agent_max_climb = 0.6
	navmesh.agent_max_slope = 48.0
	nav_region.navigation_mesh = navmesh

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	mesh_inst.mesh = malha_chunk
	mesh_inst.material_override = _material_terreno
	nav_region.add_child(mesh_inst)
	
	var trimesh_shape: ConcavePolygonShape3D = malha_chunk.create_trimesh_shape()
	if trimesh_shape != null:
		trimesh_shape.backface_collision = true
		
		var static_body := StaticBody3D.new()
		static_body.name = "StaticBody3D"
		static_body.collision_layer = 1
		static_body.collision_mask = 1
		
		var col_shape := CollisionShape3D.new()
		col_shape.name = "CollisionShape3D"
		col_shape.shape = trimesh_shape
		static_body.add_child(col_shape)
		nav_region.add_child(static_body)
	
	var vilas_node := Node3D.new()
	vilas_node.name = "Vilas"
	nav_region.add_child(vilas_node)
	var casas_posicoes := _gerar_civilizacoes_chunk(vilas_node, x_start, z_start, chunk_size_m)
	
	chunk_node.add_child(nav_region)
	_chunks_container.add_child(chunk_node)
	_chunks_ativos[coord] = chunk_node
	
	if not Engine.is_editor_hint():
		_registrar_baus_seed_chunk(coord, x_start, z_start, chunk_size_m, casas_posicoes)
		_instanciar_baus_chunk(coord, chunk_node, x_start, z_start)
		nav_region.bake_navigation_mesh()
		_registrar_inimigos_seed_chunk(coord, x_start, z_start, chunk_size_m, casas_posicoes)
	#essa linha de código é horrível porque ela recalcula todas as conexões
	#de navmesh quando você roda ele.
	return chunk_node


func _descarregar_chunk(coord: Vector2i) -> void:
	if _timers_descarregamento.has(coord):
		_timers_descarregamento.erase(coord)
	
	if not _chunks_ativos.has(coord):
		return
	
	# Congela preventivamente qualquer inimigo posicionado sobre este chunk antes de remover a colisão
	for enemy_id in _registro_inimigos.keys():
		var dados: Dictionary = _registro_inimigos[enemy_id]
		if dados["dead"]:
			continue
		var inst: Enemy = dados["instancia"] as Enemy if is_instance_valid(dados["instancia"]) else null
		if inst != null and not inst.is_dead:
			var coord_inimigo := obter_chunk_da_posicao(Vector2(inst.global_position.x, inst.global_position.z))
			if coord_inimigo == coord:
				dados["pos"] = inst.global_position
				dados["rot_y"] = inst.rotation.y
				dados["health"] = inst.health
				inst.set_culled_state(true)
	
	var chunk_node: Node3D = _chunks_ativos[coord]
	_chunks_ativos.erase(coord)
	
	if chunk_node != null and is_instance_valid(chunk_node):
		if chunk_node.get_parent() != null:
			chunk_node.get_parent().remove_child(chunk_node)
		chunk_node.queue_free()


func _gerar_civilizacoes_chunk(container: Node3D, x_start: float, z_start: float, chunk_size_m: float) -> Array[Vector2]:
	var casas_posicoes: Array[Vector2] = []
	var min_x: float = x_start
	var max_x: float = x_start + chunk_size_m
	var min_z: float = z_start
	var max_z: float = z_start + chunk_size_m
	
	var gx_start: float = floor(min_x / espacamento_grade_casas) * espacamento_grade_casas
	var gz_start: float = floor(min_z / espacamento_grade_casas) * espacamento_grade_casas
	
	var rng := RandomNumberGenerator.new()
	
	var gz: float = gz_start
	while gz <= max_z + (espacamento_grade_casas * 0.5):
		var gx: float = gx_start
		while gx <= max_x + (espacamento_grade_casas * 0.5):
			var ix_cell := int(round(gx / espacamento_grade_casas))
			var iz_cell := int(round(gz / espacamento_grade_casas))
			rng.seed = _hash_coordenadas(ix_cell, iz_cell, seed_civilizacao)
			
			var px: float = gx + rng.randf_range(-jitter_casas, jitter_casas)
			var pz: float = gz + rng.randf_range(-jitter_casas, jitter_casas)
			
			if px >= min_x and px < max_x and pz >= min_z and pz < max_z:
				if _avaliar_e_instanciar_casa_chunk(px, pz, rng, container, x_start, z_start):
					casas_posicoes.append(Vector2(px, pz))
			
			gx += espacamento_grade_casas
		gz += espacamento_grade_casas
	
	return casas_posicoes


func _avaliar_e_instanciar_casa_chunk(px: float, pz: float, rng: RandomNumberGenerator, container: Node3D, x_start: float, z_start: float) -> bool:
	var valor_civilizacao: float = noise_civilizacao.get_noise_2d(px, pz)
	if valor_civilizacao <= limiar_zona_vila:
		return false
	
	if rng.randf() > densidade_casas_na_vila:
		return false
	
	var h_centro: float = obter_altura(px, pz)
	
	var altura_minima_planicie: float = 0.05
	var altura_teto_planicie: float = altura_inicio_rocha - 0.5
	if h_centro <= altura_minima_planicie or h_centro >= altura_teto_planicie:
		return false
	
	var delta_amostragem: float = 1.8
	var h_norte: float = obter_altura(px, pz - delta_amostragem)
	var h_sul: float   = obter_altura(px, pz + delta_amostragem)
	var h_leste: float = obter_altura(px + delta_amostragem, pz)
	var h_oeste: float = obter_altura(px - delta_amostragem, pz)
	
	var diff_n: float = absf(h_centro - h_norte)
	var diff_s: float = absf(h_centro - h_sul)
	var diff_l: float = absf(h_centro - h_leste)
	var diff_o: float = absf(h_centro - h_oeste)
	
	var inclinacao_maxima_local: float = maxf(maxf(diff_n, diff_s), maxf(diff_l, diff_o))
	if inclinacao_maxima_local > inclinacao_maxima_casa:
		return false
	
	var instancia_casa: Node3D
	if cena_casa != null:
		instancia_casa = cena_casa.instantiate() as Node3D
	else:
		instancia_casa = _criar_casa_fallback_procedural(rng)
	
	if instancia_casa == null:
		return false
	
	instancia_casa.position = Vector3(px - x_start, h_centro, pz - z_start)
	instancia_casa.rotation.y = rng.randf_range(0.0, TAU)
	
	container.add_child(instancia_casa)
	return true


func _registrar_baus_seed_chunk(coord: Vector2i, x_start: float, z_start: float, chunk_size_m: float, casas_posicoes: Array[Vector2]) -> void:
	if not gerar_baus or _chunks_baus_gerados.has(coord):
		return
	
	_chunks_baus_gerados[coord] = true
	
	var seed_baus: int = seed_terreno ^ (seed_civilizacao * 31) ^ seed_baus_offset
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash_coordenadas(coord.x, coord.y, seed_baus)
	
	var baus_posicoes_chunk: Array[Vector2] = []
	var baus_vila_criados: int = 0
	for idx_casa in range(casas_posicoes.size()):
		if baus_vila_criados >= max_baus_por_chunk_vila:
			break
		if rng.randf() > chance_bau_vila:
			continue
		
		var casa_pos: Vector2 = casas_posicoes[idx_casa]
		var ang_base: float = rng.randf_range(0.0, TAU)
		for tentativa in range(6):
			var ang: float = ang_base + float(tentativa) * (TAU / 6.0)
			var dist_casa: float = rng.randf_range(2.6, 3.4)
			var bx: float = casa_pos.x + cos(ang) * dist_casa
			var bz: float = casa_pos.y + sin(ang) * dist_casa
			
			if bx < x_start + 1.0 or bx >= x_start + chunk_size_m - 1.0 or bz < z_start + 1.0 or bz >= z_start + chunk_size_m - 1.0:
				continue
			
			if _ponto_spawn_bau_valido(bx, bz, casas_posicoes, baus_posicoes_chunk):
				var bh: float = obter_altura(bx, bz)
				var chest_id := "bau_vila_%d_%d_%d" % [coord.x, coord.y, baus_vila_criados]
				var tier: int = 1 if rng.randf() < 0.35 else 0
				var loot_items := InventoryUI.generate_survival_chest_loot(rng, tier)
				var rot_y: float = atan2(bx - casa_pos.x, bz - casa_pos.y)
				_registro_baus[chest_id] = {
					"id": chest_id,
					"coord": coord,
					"pos": Vector3(bx, bh, bz),
					"rot_y": rot_y,
					"opened": false,
					"loot": loot_items
				}
				baus_posicoes_chunk.append(Vector2(bx, bz))
				baus_vila_criados += 1
				break
	
	# Baú ocasional nas planícies
	var rng_plan := RandomNumberGenerator.new()
	rng_plan.seed = _hash_coordenadas(coord.x, coord.y, seed_terreno ^ (seed_baus_offset * 59))
	if rng_plan.randf() <= chance_bau_planicie:
		var margem: float = 4.0
		for tentativa in range(6):
			var bx: float = rng_plan.randf_range(x_start + margem, x_start + chunk_size_m - margem)
			var bz: float = rng_plan.randf_range(z_start + margem, z_start + chunk_size_m - margem)
			if _ponto_spawn_bau_valido(bx, bz, casas_posicoes, baus_posicoes_chunk):
				var bh: float = obter_altura(bx, bz)
				var chest_id := "bau_planicie_%d_%d" % [coord.x, coord.y]
				var loot_items := InventoryUI.generate_survival_chest_loot(rng_plan, 0)
				_registro_baus[chest_id] = {
					"id": chest_id,
					"coord": coord,
					"pos": Vector3(bx, bh, bz),
					"rot_y": rng_plan.randf_range(0.0, TAU),
					"opened": false,
					"loot": loot_items
				}
				break


func _ponto_spawn_bau_valido(bx: float, bz: float, casas_posicoes: Array[Vector2], baus_existentes: Array[Vector2]) -> bool:
	var bh: float = obter_altura(bx, bz)
	if bh <= 0.12 or bh >= (altura_inicio_rocha - 0.5):
		return false
	
	var d_amostra: float = 1.0
	var diff_max: float = maxf(
		maxf(absf(bh - obter_altura(bx, bz - d_amostra)), absf(bh - obter_altura(bx, bz + d_amostra))),
		maxf(absf(bh - obter_altura(bx + d_amostra, bz)), absf(bh - obter_altura(bx - d_amostra, bz)))
	)
	if diff_max > (inclinacao_maxima_casa + 0.15):
		return false
	
	var cand := Vector2(bx, bz)
	for casa_pos in casas_posicoes:
		if cand.distance_to(casa_pos) < 2.35:
			return false
	for b_pos in baus_existentes:
		if cand.distance_to(b_pos) < 3.0:
			return false
	return true


func _instanciar_baus_chunk(coord: Vector2i, chunk_node: Node3D, x_start: float, z_start: float) -> void:
	if not gerar_baus:
		return
	var baus_node := Node3D.new()
	baus_node.name = "Baus"
	chunk_node.add_child(baus_node)
	
	for chest_id: String in _registro_baus.keys():
		var dados: Dictionary = _registro_baus[chest_id]
		if dados["coord"] != coord:
			continue
		var bau := LootChest.new()
		bau.name = "LootChest_%s" % chest_id
		var pos_mundo: Vector3 = dados["pos"]
		bau.position = Vector3(pos_mundo.x - x_start, pos_mundo.y, pos_mundo.z - z_start)
		bau.rotation.y = float(dados["rot_y"])
		baus_node.add_child(bau)
		var loot_typed: Array[Dictionary] = []
		for entry in dados["loot"]:
			if entry is Dictionary:
				loot_typed.append(entry as Dictionary)
		bau.setup(chest_id, loot_typed, bool(dados["opened"]))
		if not bau.chest_opened.is_connected(_on_bau_aberto):
			bau.chest_opened.connect(_on_bau_aberto)


func _on_bau_aberto(chest_id: String) -> void:
	if _registro_baus.has(chest_id):
		_registro_baus[chest_id]["opened"] = true
		_registro_baus[chest_id]["loot"] = []


func _obter_nivel_ameaca() -> int:
	if not escalar_dificuldade_tempo:
		return 1
	return 1 + int(floor(_tempo_sobrevivencia / 45.0))


func _registrar_inimigos_seed_chunk(coord: Vector2i, x_start: float, z_start: float, chunk_size_m: float, casas_posicoes: Array[Vector2]) -> void:
	if not gerar_inimigos or cena_inimigo == null or _chunks_inimigos_gerados.has(coord):
		return
	
	_chunks_inimigos_gerados[coord] = true
	
	var seed_combinada: int = seed_terreno ^ (seed_civilizacao * 17) ^ seed_inimigos_offset
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash_coordenadas(coord.x, coord.y, seed_combinada)
	
	var nivel_ameaca := _obter_nivel_ameaca()
	var bonus_vila: int = clampi(int(floor(float(nivel_ameaca - 1) * 0.75)), 0, 4)
	var max_vila_efetivo: int = max_inimigos_por_chunk_vila + bonus_vila
	var chance_vila_efetiva: float = minf(0.95, chance_inimigo_vila + float(nivel_ameaca - 1) * 0.06)
	
	var inimigos_vila_criados: int = 0
	for idx_casa in range(casas_posicoes.size()):
		if inimigos_vila_criados >= max_vila_efetivo:
			break
		if rng.randf() > chance_vila_efetiva:
			continue
		
		var casa_pos: Vector2 = casas_posicoes[idx_casa]
		var angulo_base: float = rng.randf_range(0.0, TAU)
		for tentativa in range(6):
			var ang: float = angulo_base + float(tentativa) * (TAU / 6.0)
			var dist_casa: float = rng.randf_range(4.2, 5.4)
			var ex: float = casa_pos.x + cos(ang) * dist_casa
			var ez: float = casa_pos.y + sin(ang) * dist_casa
			
			if ex < x_start + 1.0 or ex >= x_start + chunk_size_m - 1.0 or ez < z_start + 1.0 or ez >= z_start + chunk_size_m - 1.0:
				continue
			
			if _ponto_spawn_inimigo_valido(ex, ez, casas_posicoes):
				var eh: float = obter_altura(ex, ez)
				var enemy_id := "vila_%d_%d_%d" % [coord.x, coord.y, inimigos_vila_criados]
				var pos_spawn := Vector3(ex, eh + 1.05, ez)
				_registro_inimigos[enemy_id] = {
					"id": enemy_id,
					"dead": false,
					"pos": pos_spawn,
					"home_pos": pos_spawn,
					"rot_y": rng.randf_range(0.0, TAU),
					"health": -1.0,
					"alert_player": false,
					"instancia": null
				}
				inimigos_vila_criados += 1
				break
	
	# Geração ocasional de inimigos espalhados pelas planícies (escala com o tempo de sobrevivência)
	var rng_planicie := RandomNumberGenerator.new()
	rng_planicie.seed = _hash_coordenadas(coord.x, coord.y, seed_terreno ^ (seed_inimigos_offset * 73))
	var chance_planicie_efetiva: float = minf(0.85, chance_inimigo_planicie + float(nivel_ameaca - 1) * 0.08)
	var qtd_tentativas_planicie: int = clampi(1 + int(floor(float(nivel_ameaca - 1) * 0.5)), 1, 3)
	for slot_plan in range(qtd_tentativas_planicie):
		if rng_planicie.randf() <= chance_planicie_efetiva:
			var margem: float = 4.0
			for tentativa in range(6):
				var ex: float = rng_planicie.randf_range(x_start + margem, x_start + chunk_size_m - margem)
				var ez: float = rng_planicie.randf_range(z_start + margem, z_start + chunk_size_m - margem)
				if _ponto_spawn_inimigo_valido(ex, ez, casas_posicoes):
					var eh: float = obter_altura(ex, ez)
					var enemy_id := "planicie_%d_%d_%d" % [coord.x, coord.y, slot_plan]
					var pos_spawn := Vector3(ex, eh + 1.05, ez)
					_registro_inimigos[enemy_id] = {
						"id": enemy_id,
						"dead": false,
						"pos": pos_spawn,
						"home_pos": pos_spawn,
						"rot_y": rng_planicie.randf_range(0.0, TAU),
						"health": -1.0,
						"alert_player": false,
						"instancia": null
					}
					break


func _processar_ondas_inimigos(delta: float, pos_jogador_xz: Vector2) -> void:
	if not gerar_inimigos or cena_inimigo == null:
		return
	
	_timer_proxima_onda -= delta
	if _timer_proxima_onda > 0.0:
		return
	
	var nivel_ameaca := _obter_nivel_ameaca()
	var intervalo_atual := maxf(intervalo_minimo_ondas, intervalo_inicial_ondas - float(nivel_ameaca - 1) * 2.4)
	if Enemy.is_night_time:
		intervalo_atual *= 0.82
	_timer_proxima_onda = intervalo_atual
	
	# Conta inimigos vivos e ativos próximos para não sobrecarregar a cena
	var vivos_proximos: int = 0
	for enemy_id in _registro_inimigos.keys():
		var dados: Dictionary = _registro_inimigos[enemy_id]
		if dados["dead"]:
			continue
		var inst: Enemy = dados["instancia"] as Enemy if is_instance_valid(dados["instancia"]) else null
		if inst != null and not inst.is_dead and not inst.is_culled:
			vivos_proximos += 1
	
	if vivos_proximos >= max_inimigos_vivos_simultaneos:
		return
	
	_contador_ondas += 1
	var qtd_onda: int = clampi(1 + int(floor(float(nivel_ameaca) * 0.75)), 1, 5)
	if Enemy.is_night_time:
		qtd_onda = min(6, qtd_onda + 1)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash_coordenadas(_contador_ondas, int(_tempo_sobrevivencia * 10.0), seed_terreno ^ seed_inimigos_offset)
	
	var vazios_casas: Array[Vector2] = []
	var criados_onda: int = 0
	for i in range(qtd_onda):
		if vivos_proximos + criados_onda >= max_inimigos_vivos_simultaneos:
			break
		for tentativa in range(10):
			var ang: float = rng.randf_range(0.0, TAU)
			var dist: float = rng.randf_range(34.0, 52.0)
			var ex: float = pos_jogador_xz.x + cos(ang) * dist
			var ez: float = pos_jogador_xz.y + sin(ang) * dist
			var coord := obter_chunk_da_posicao(Vector2(ex, ez))
			if not _chunks_ativos.has(coord):
				continue
			if _ponto_spawn_inimigo_valido(ex, ez, vazios_casas):
				var eh: float = obter_altura(ex, ez)
				var enemy_id := "onda_%d_%d" % [_contador_ondas, i]
				var pos_spawn := Vector3(ex, eh + 1.05, ez)
				_registro_inimigos[enemy_id] = {
					"id": enemy_id,
					"dead": false,
					"pos": pos_spawn,
					"home_pos": pos_spawn,
					"rot_y": atan2(pos_jogador_xz.x - ex, pos_jogador_xz.y - ez),
					"health": -1.0,
					"alert_player": true,
					"instancia": null
				}
				criados_onda += 1
				break


func _ponto_spawn_inimigo_valido(ex: float, ez: float, casas_posicoes: Array[Vector2]) -> bool:
	var pos_cand := Vector2(ex, ez)
	if _tempo_sobrevivencia < 5.0 and pos_cand.distance_to(_pos_inicial_player_xz) < distancia_segura_spawn_player:
		return false
	
	var eh: float = obter_altura(ex, ez)
	if eh <= 0.18 or eh >= (altura_inicio_rocha - 0.5):
		return false
	
	var d_amostra: float = 1.6
	var diff_max: float = maxf(
		maxf(absf(eh - obter_altura(ex, ez - d_amostra)), absf(eh - obter_altura(ex, ez + d_amostra))),
		maxf(absf(eh - obter_altura(ex + d_amostra, ez)), absf(eh - obter_altura(ex - d_amostra, ez)))
	)
	if diff_max > (inclinacao_maxima_casa + 0.2):
		return false
	
	for casa_pos in casas_posicoes:
		if pos_cand.distance_to(casa_pos) < 3.9:
			return false
	
	return true


func _atualizar_estado_inimigos(pos_jogador_xz: Vector2) -> void:
	if Engine.is_editor_hint() or not gerar_inimigos or cena_inimigo == null:
		return
	
	var chunk_size_m: float = float(tamanho_chunk) * resolucao_vertice
	var dist_liberar_instancia: float = (float(distancia_visao_chunks) + 2.5) * chunk_size_m
	
	for enemy_id in _registro_inimigos.keys():
		var dados: Dictionary = _registro_inimigos[enemy_id]
		if dados["dead"]:
			continue
		
		var inst: Enemy = dados["instancia"] as Enemy if is_instance_valid(dados["instancia"]) else null
		if inst != null and inst.is_dead:
			dados["dead"] = true
			dados["instancia"] = null
			continue
		
		var pos_atual: Vector3 = inst.global_position if inst != null else dados["pos"]
		var coord_atual := obter_chunk_da_posicao(Vector2(pos_atual.x, pos_atual.z))
		var chunk_ativo := _chunks_ativos.has(coord_atual)
		var dist_player := pos_jogador_xz.distance_to(Vector2(pos_atual.x, pos_atual.z))
		
		if chunk_ativo:
			if inst == null:
				var novo_inimigo := cena_inimigo.instantiate() as Enemy
				if novo_inimigo != null:
					novo_inimigo.name = "Enemy_%s" % enemy_id
					novo_inimigo.enemy_id = enemy_id
					novo_inimigo.gerador_terreno = self
					novo_inimigo.home_position = dados["home_pos"]
					_inimigos_container.add_child(novo_inimigo)
					var h_chao: float = obter_altura(pos_atual.x, pos_atual.z) + 1.05
					novo_inimigo.global_position = Vector3(pos_atual.x, maxf(pos_atual.y, h_chao), pos_atual.z)
					novo_inimigo.rotation.y = dados["rot_y"]
					if dados["health"] > 0.0:
						novo_inimigo.health = dados["health"]
					if not novo_inimigo.died.is_connected(_on_inimigo_morreu):
						novo_inimigo.died.connect(_on_inimigo_morreu)
					if dados.get("alert_player", false):
						dados["alert_player"] = false
						var target_p := _obter_player()
						if target_p != null:
							novo_inimigo.hear_sound(target_p.global_position, true)
					dados["instancia"] = novo_inimigo
			else:
				if inst.is_culled:
					var h_chao: float = obter_altura(inst.global_position.x, inst.global_position.z) + 1.05
					if inst.global_position.y < h_chao:
						inst.global_position.y = h_chao
					inst.set_culled_state(false)
				dados["pos"] = inst.global_position
				dados["rot_y"] = inst.rotation.y
				dados["health"] = inst.health
		else:
			if inst != null:
				dados["pos"] = inst.global_position
				dados["rot_y"] = inst.rotation.y
				dados["health"] = inst.health
				if dist_player > dist_liberar_instancia:
					dados["instancia"] = null
					inst.queue_free()
				else:
					inst.set_culled_state(true)


func _on_inimigo_morreu(enemy_id: String) -> void:
	if _registro_inimigos.has(enemy_id):
		if not _registro_inimigos[enemy_id].get("dead", false):
			_inimigos_eliminados += 1
		_registro_inimigos[enemy_id]["dead"] = true
		_registro_inimigos[enemy_id]["instancia"] = null
	else:
		_inimigos_eliminados += 1


func get_tempo_sobrevivencia() -> float:
	return _tempo_sobrevivencia


func get_inimigos_eliminados() -> int:
	return _inimigos_eliminados



func _criar_casa_fallback_procedural(rng: RandomNumberGenerator) -> Node3D:
	var raiz_casa := StaticBody3D.new()
	raiz_casa.name = "CasaProcedural"
	raiz_casa.collision_layer = 1
	raiz_casa.collision_mask = 1
	
	var escala_var: float = rng.randf_range(0.85, 1.15)
	var largura: float = 3.2 * escala_var
	var altura_parede: float = 2.4 * escala_var
	var profundidade: float = 3.0 * escala_var
	var altura_telhado: float = 1.4 * escala_var
	
	var mesh_base := MeshInstance3D.new()
	mesh_base.name = "Paredes"
	var box := BoxMesh.new()
	box.size = Vector3(largura, altura_parede, profundidade)
	mesh_base.mesh = box
	mesh_base.material_override = _material_base_casa
	mesh_base.position = Vector3(0.0, altura_parede * 0.5, 0.0)
	raiz_casa.add_child(mesh_base)
	
	var mesh_telhado := MeshInstance3D.new()
	mesh_telhado.name = "Telhado"
	var prisma := PrismMesh.new()
	prisma.size = Vector3(largura * 1.1, altura_telhado, profundidade * 1.08)
	mesh_telhado.mesh = prisma
	mesh_telhado.material_override = _material_telhado_casa
	mesh_telhado.position = Vector3(0.0, altura_parede + (altura_telhado * 0.5), 0.0)
	raiz_casa.add_child(mesh_telhado)
	
	var colisor := CollisionShape3D.new()
	colisor.name = "CollisionShape3D"
	var shape_box := BoxShape3D.new()
	var altura_total: float = altura_parede + altura_telhado
	shape_box.size = Vector3(largura, altura_total, profundidade)
	colisor.shape = shape_box
	colisor.position = Vector3(0.0, altura_total * 0.5, 0.0)
	raiz_casa.add_child(colisor)
	
	return raiz_casa


func _hash_coordenadas(x: int, z: int, s: int) -> int:
	var h: int = s
	h = (h ^ (x * 73856093)) ^ (z * 19349663)
	return abs(h)


func obter_altura_terreno(x: float, z: float) -> float:
	return obter_altura(x, z)


func obter_altura(x: float, z: float) -> float:
	var raw_n: float = noise_terreno.get_noise_2d(x, z)
	
	if raw_n < 0.0:
		return raw_n * profundidade_maxima_agua
	
	if raw_n < limiar_montanhas:
		var t_planicie: float = raw_n / limiar_montanhas
		return t_planicie * altura_maxima_planicie
	
	var t_montanha: float = (raw_n - limiar_montanhas) / (1.0 - limiar_montanhas)
	var fator_potencia: float = pow(t_montanha, expoente_montanhas)
	return altura_maxima_planicie + (fator_potencia * altura_maxima_montanhas)


func obter_cor_vertice(altura: float) -> Color:
	if altura < 0.0:
		if altura >= -0.3:
			var t_areia: float = (altura + 0.3) / 0.3
			return cor_areia.lerp(cor_grama, t_areia * 0.3)
		return cor_areia
	
	if altura < altura_inicio_rocha:
		if altura <= 0.3:
			var t_costa: float = altura / 0.3
			return cor_areia.lerp(cor_grama, t_costa)
		elif altura > (altura_inicio_rocha - 1.2):
			var t_rocha: float = (altura - (altura_inicio_rocha - 1.2)) / 1.2
			return cor_grama.lerp(cor_rocha, t_rocha)
		return cor_grama
	
	if altura < altura_inicio_neve:
		var intervalo_rocha: float = max(0.1, altura_inicio_neve - altura_inicio_rocha)
		var t_meio_montanha: float = (altura - altura_inicio_rocha) / intervalo_rocha
		return cor_rocha.lerp(cor_neve, clampf(t_meio_montanha * 0.25, 0.0, 0.25))
	
	var topo_max: float = max(altura_inicio_neve + 0.1, altura_maxima_planicie + altura_maxima_montanhas)
	var t_neve: float = (altura - altura_inicio_neve) / (topo_max - altura_inicio_neve)
	return cor_rocha.lerp(cor_neve, clampf(0.25 + (t_neve * 0.75), 0.0, 1.0))


func _obter_direcao_visao(target_player: CharacterBody3D) -> Vector2:
	var cam := _obter_camera()
	var dir: Vector2 = Vector2.ZERO
	if cam != null and is_instance_valid(cam):
		var fwd3d: Vector3 = -cam.global_transform.basis.z
		dir = Vector2(fwd3d.x, fwd3d.z)
	
	if dir.length_squared() < 0.01:
		var pfwd3d: Vector3 = -target_player.global_transform.basis.z
		dir = Vector2(pfwd3d.x, pfwd3d.z)
	
	if dir.length_squared() < 0.001:
		dir = Vector2(0.0, -1.0)
	else:
		dir = dir.normalized()
	
	return dir


func _obter_camera() -> Camera3D:
	if _camera != null and is_instance_valid(_camera) and _camera.is_inside_tree():
		return _camera
	
	var target_player := _obter_player()
	if target_player != null and is_instance_valid(target_player):
		_camera = target_player.find_child("Camera", true, false) as Camera3D
		if _camera != null:
			return _camera
		_camera = target_player.find_child("Camera3D", true, false) as Camera3D
		if _camera != null:
			return _camera
	
	if get_viewport() != null:
		_camera = get_viewport().get_camera_3d()
		if _camera != null:
			return _camera
	
	return null


func _obter_player() -> CharacterBody3D:
	if player != null and is_instance_valid(player) and player.is_inside_tree():
		return player
	
	if get_parent() != null:
		player = get_parent().find_child("Player", true, false) as CharacterBody3D
	if player == null and is_inside_tree() and get_tree() != null and get_tree().root != null:
		player = get_tree().root.find_child("Player", true, false) as CharacterBody3D
	
	return player


func _garantir_player_no_chao() -> void:
	var target_player := _obter_player()
	if target_player != null:
		var px: float = target_player.global_position.x
		var pz: float = target_player.global_position.z
		var h_terreno: float = obter_altura(px, pz)
		target_player.global_position.y = h_terreno + 1.8
		target_player.velocity = Vector3.ZERO
		_player_posicionado = true


func regenerar_tudo() -> void:
	_inicializar_ruidos()
	_inicializar_materiais()
	_preparar_chunks_container()
	
	if Engine.is_editor_hint():
		_gerar_preview_editor()
		return
	
	if ativar_nevoa:
		_configurar_nevoa()
	
	var target_player := _obter_player()
	var pos_jogador_xz := Vector2.ZERO
	if target_player != null:
		pos_jogador_xz = Vector2(target_player.global_position.x, target_player.global_position.z)
	_pos_inicial_player_xz = pos_jogador_xz
	
	var chunk_size_m: float = float(tamanho_chunk) * resolucao_vertice
	var p_cx: int = int(floor(pos_jogador_xz.x / chunk_size_m))
	var p_cz: int = int(floor(pos_jogador_xz.y / chunk_size_m))
	
	for dx in range(-raio_seguranca_chunks, raio_seguranca_chunks + 1):
		for dz in range(-raio_seguranca_chunks, raio_seguranca_chunks + 1):
			var coord := Vector2i(p_cx + dx, p_cz + dz)
			_gerar_chunk(coord)
	
	if posicionar_player_no_chao and target_player != null:
		_garantir_player_no_chao()
	
	_atualizar_estado_inimigos(pos_jogador_xz)


func _gerar_preview_editor() -> void:
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			_gerar_chunk(Vector2i(dx, dz))
