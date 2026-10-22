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

@export_group("Ajuste de Jogador (Anti-Queda)")
@export var posicionar_player_no_chao: bool = true
@export var player: CharacterBody3D

@export_group("Navegação")
@export var navmesh: NavigationMesh
@export var region_rid: RID

var noise_terreno: FastNoiseLite
var noise_civilizacao: FastNoiseLite

var _chunks_container: Node3D
var _material_terreno: StandardMaterial3D
var _material_base_casa: StandardMaterial3D
var _material_telhado_casa: StandardMaterial3D

var _camera: Camera3D

var _chunks_ativos: Dictionary = {}
var _timers_descarregamento: Dictionary = {}
var _fila_geracao: Array[Vector2i] = []
var _na_fila: Dictionary = {}

var _ultima_pos_jogador_xz: Vector2 = Vector2(INF, INF)
var _ultima_dir_visao: Vector2 = Vector2.ZERO
var _player_posicionado: bool = false


func _ready() -> void:
	_inicializar_ruidos()
	_inicializar_materiais()
	_preparar_chunks_container()
	
	if Engine.is_editor_hint():
		if gerar_no_ready:
			_gerar_preview_editor()
		return
	
	if ativar_nevoa:
		_configurar_nevoa()
	
	var target_player := _obter_player()
	var pos_jogador_xz := Vector2.ZERO
	if target_player != null:
		pos_jogador_xz = Vector2(target_player.global_position.x, target_player.global_position.z)
	
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
	_inicializar_navegacao()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	_processar_timers_descarregamento(delta)
	
	var target_player := _obter_player()
	if target_player == null:
		return
	
	var pos_jogador_xz := Vector2(target_player.global_position.x, target_player.global_position.z)
	var dir_visao := _obter_direcao_visao(target_player)
	
	var deslocou: bool = pos_jogador_xz.distance_squared_to(_ultima_pos_jogador_xz) > 1.5
	var girou: bool = dir_visao.dot(_ultima_dir_visao) < 0.996
	
	if deslocou or girou or not _fila_geracao.is_empty():
		_ultima_pos_jogador_xz = pos_jogador_xz
		_ultima_dir_visao = dir_visao
		_atualizar_visibilidade_chunks(pos_jogador_xz, dir_visao)
	
	_processar_fila_geracao()


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
		if filho.name != "Chunks":
			filho.queue_free()
	
	if _chunks_container == null or not is_instance_valid(_chunks_container):
		_chunks_container = get_node_or_null("Chunks") as Node3D
		if _chunks_container == null:
			_chunks_container = Node3D.new()
			_chunks_container.name = "Chunks"
			add_child(_chunks_container)
	
	for c in _chunks_container.get_children():
		c.queue_free()
	
	_chunks_ativos.clear()
	_timers_descarregamento.clear()
	_fila_geracao.clear()
	_na_fila.clear()


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
			
			if dist <= dist_max_m:
				var dir_chunk := to_chunk / dist
				var dot := dir_visao.dot(dir_chunk)
				if dot >= cos_load_cone:
					chunks_desejados[coord] = dist
	
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
			
			if dist <= raio_seguranca_m:
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
	
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	mesh_inst.mesh = malha_chunk
	mesh_inst.material_override = _material_terreno
	chunk_node.add_child(mesh_inst)
	
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
		chunk_node.add_child(static_body)
	
	var vilas_node := Node3D.new()
	vilas_node.name = "Vilas"
	chunk_node.add_child(vilas_node)
	_gerar_civilizacoes_chunk(vilas_node, x_start, z_start, chunk_size_m)
	
	_chunks_container.add_child(chunk_node)
	_chunks_ativos[coord] = chunk_node
	
	return chunk_node


func _descarregar_chunk(coord: Vector2i) -> void:
	if _timers_descarregamento.has(coord):
		_timers_descarregamento.erase(coord)
	
	if not _chunks_ativos.has(coord):
		return
	
	var chunk_node: Node3D = _chunks_ativos[coord]
	_chunks_ativos.erase(coord)
	
	if chunk_node != null and is_instance_valid(chunk_node):
		if chunk_node.get_parent() != null:
			chunk_node.get_parent().remove_child(chunk_node)
		chunk_node.queue_free()


func _gerar_civilizacoes_chunk(container: Node3D, x_start: float, z_start: float, chunk_size_m: float) -> void:
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
				_avaliar_e_instanciar_casa_chunk(px, pz, rng, container, x_start, z_start)
			
			gx += espacamento_grade_casas
		gz += espacamento_grade_casas


func _avaliar_e_instanciar_casa_chunk(px: float, pz: float, rng: RandomNumberGenerator, container: Node3D, x_start: float, z_start: float) -> void:
	var valor_civilizacao: float = noise_civilizacao.get_noise_2d(px, pz)
	if valor_civilizacao <= limiar_zona_vila:
		return
	
	if rng.randf() > densidade_casas_na_vila:
		return
	
	var h_centro: float = obter_altura(px, pz)
	
	var altura_minima_planicie: float = 0.05
	var altura_teto_planicie: float = altura_inicio_rocha - 0.5
	if h_centro <= altura_minima_planicie or h_centro >= altura_teto_planicie:
		return
	
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
		return
	
	var instancia_casa: Node3D
	if cena_casa != null:
		instancia_casa = cena_casa.instantiate() as Node3D
	else:
		instancia_casa = _criar_casa_fallback_procedural(rng)
	
	if instancia_casa == null:
		return
	
	instancia_casa.position = Vector3(px - x_start, h_centro, pz - z_start)
	instancia_casa.rotation.y = rng.randf_range(0.0, TAU)
	
	container.add_child(instancia_casa)


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
	
	var chunk_size_m: float = float(tamanho_chunk) * resolucao_vertice
	var p_cx: int = int(floor(pos_jogador_xz.x / chunk_size_m))
	var p_cz: int = int(floor(pos_jogador_xz.y / chunk_size_m))
	
	for dx in range(-raio_seguranca_chunks, raio_seguranca_chunks + 1):
		for dz in range(-raio_seguranca_chunks, raio_seguranca_chunks + 1):
			var coord := Vector2i(p_cx + dx, p_cz + dz)
			_gerar_chunk(coord)
	
	if posicionar_player_no_chao and target_player != null:
		_garantir_player_no_chao()


func _gerar_preview_editor() -> void:
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			_gerar_chunk(Vector2i(dx, dz))

#region Navigation

func _inicializar_navegacao() -> void:
	navmesh = NavigationMesh.new()
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navmesh.geometry_source_group_name = 'terreno'
	region_rid = NavigationServer3D.region_create()
	NavigationServer3D.region_set_enabled(region_rid,true)
	NavigationServer3D.region_set_map(region_rid,get_world_3d().get_navigation_map())
	
	navmesh.vertices = PackedVector3Array(
		[Vector3(-1.0, 0.0, 1.0),
		Vector3(1.0, 0.0, 1.0),
		Vector3(1.0, 0.0, -1.0),
		Vector3(-1.0, 0.0, -1.0),])
	navmesh.add_polygon(PackedInt32Array([0,1,2,3]))
	NavigationServer3D.region_set_navigation_mesh(region_rid,navmesh)
