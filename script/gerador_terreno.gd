@tool
class_name GeradorTerreno
extends Node3D

## Sistema Completo de Geração de Terreno Procedural 3D para Godot 4.x
## Utiliza FastNoiseLite e SurfaceTool com colisão Trimesh, colorização por Vertex Colors
## e posicionamento orgânico de comunidades de civilização em planícies.

# ==============================================================================
# PROPRIEDADES EXPORTADAS (INSPECTOR)
# ==============================================================================

@export_group("Geração no Editor / Runtime")
## Se ativo, gera o terreno automaticamente assim que a cena é carregada no _ready()
@export var gerar_no_ready: bool = true
## Marque esta caixa no Inspector para regenerar o terreno e vilas imediatamente
@export var regenerar_terreno: bool = false:
	set(valor):
		if valor and is_inside_tree():
			gerar_tudo()

@export_group("Dimensões do Terreno")
## Número de células nos eixos X e Z (resolução da grade)
@export var tamanho_terreno: Vector2i = Vector2i(150, 150)
## Espaçamento em metros entre os vértices da malha
@export_range(0.2, 5.0, 0.1) var resolucao_vertice: float = 1.0
## Se ativo, centraliza o terreno na origem (0, 0, 0)
@export var centralizar_terreno: bool = true

@export_group("Topografia e Elevação")
## Altura máxima das montanhas mais elevadas (metros)
@export_range(5.0, 100.0, 1.0) var altura_maxima_montanhas: float = 30.0
## Profundidade máxima das bacias de água/depressões (metros)
@export_range(1.0, 30.0, 0.5) var profundidade_maxima_agua: float = 6.0
## Elevação sutil máxima da planície para que não seja 100% plana artificialmente
@export_range(0.0, 3.0, 0.1) var altura_maxima_planicie: float = 1.0
## Limiar do ruído (0.0 a 1.0) acima do qual começam a surgir montanhas isoladas
@export_range(0.1, 0.8, 0.01) var limiar_montanhas: float = 0.45
## Expoente matemático da montanha. Quanto maior, mais planas são as planícies e mais isolados e íngremes os picos
@export_range(1.5, 6.0, 0.1) var expoente_montanhas: float = 3.0

@export_group("Ruído da Topografia (FastNoiseLite)")
## Semente aleatória do ruído do terreno
@export var seed_terreno: int = 1337:
	set(valor):
		seed_terreno = valor
		_inicializar_ruidos()
## Frequência do ruído do terreno (valores baixos geram formações mais amplas)
@export_range(0.001, 0.05, 0.001) var frequencia_terreno: float = 0.008:
	set(valor):
		frequencia_terreno = valor
		_inicializar_ruidos()
## Número de oitavas fractais (detalhes finos do terreno)
@export_range(1, 8, 1) var oitavas_terreno: int = 4:
	set(valor):
		oitavas_terreno = valor
		_inicializar_ruidos()

@export_group("Sistema de Cores (Vertex Colors)")
## Areia do fundo e margens de bacias de água (< 0.0m)
@export var cor_areia: Color = Color(0.95, 0.85, 0.45)
## Grama das planícies (entre 0.0m e início da montanha)
@export var cor_grama: Color = Color(0.35, 0.65, 0.25)
## Rocha das encostas das montanhas
@export var cor_rocha: Color = Color(0.45, 0.45, 0.45)
## Neve nos picos das montanhas
@export var cor_neve: Color = Color(0.95, 0.95, 0.95)
## Altura em que a transição de grama para rocha se consolida
@export_range(1.0, 20.0, 0.5) var altura_inicio_rocha: float = 3.5
## Altura em que a rocha dá lugar à neve nos cumes
@export_range(10.0, 80.0, 1.0) var altura_inicio_neve: float = 18.0

@export_group("Civilização e Vilarejos")
## Cena opcional de casa customizada. Se null, o gerador criará casas procedurais com Box e Prism
@export var cena_casa: PackedScene
## Semente do ruído de civilização
@export var seed_civilizacao: int = 9999:
	set(valor):
		seed_civilizacao = valor
		_inicializar_ruidos()
## Frequência do ruído de vilas (frequência baixa agrupa casas em comunidades espaçadas)
@export_range(0.002, 0.08, 0.002) var frequencia_civilizacao: float = 0.015:
	set(valor):
		frequencia_civilizacao = valor
		_inicializar_ruidos()
## Limiar do ruído de civilização para ativar uma zona de vila (ex: > 0.35)
@export_range(0.1, 0.7, 0.02) var limiar_zona_vila: float = 0.35
## Distância média da grade de verificação de casas (em metros)
@export_range(4.0, 25.0, 0.5) var espacamento_grade_casas: float = 8.5
## Deslocamento aleatório da posição na grade para layout orgânico (metros)
@export_range(0.0, 5.0, 0.2) var jitter_casas: float = 2.8
## Inclinação máxima aceita (diferença máx. de altura entre centro e vizinhos imediatos)
@export_range(0.05, 1.5, 0.05) var inclinacao_maxima_casa: float = 0.35
## Chance percentual de gerar uma casa em um ponto válido (para densidade natural na vila)
@export_range(0.2, 1.0, 0.05) var densidade_casas_na_vila: float = 0.85

@export_group("Ajuste de Jogador (Anti-Queda)")
## Se ativo, ajusta automaticamente a altura inicial do Player para que ele nasça confortavelmente sobre o terreno
@export var posicionar_player_no_chao: bool = true
## Referência opcional ao Player (se null, detecta automaticamente o nó 'Player' na cena)
@export var player: CharacterBody3D

# ==============================================================================
# VARIÁVEIS INTERNAS
# ==============================================================================

var noise_terreno: FastNoiseLite
var noise_civilizacao: FastNoiseLite

# Referências a nós gerenciados internamente
var _terreno_mesh_instance: MeshInstance3D
var _terreno_static_body: StaticBody3D
var _terreno_collision_shape: CollisionShape3D
var _vilas_container: Node3D

# Materiais reutilizáveis para o fallback procedural das casas
var _material_base_casa: StandardMaterial3D
var _material_telhado_casa: StandardMaterial3D

# ==============================================================================
# CICLO DE VIDA
# ==============================================================================

func _ready() -> void:
	_inicializar_ruidos()
	_inicializar_materiais_fallback()
	
	if gerar_no_ready:
		gerar_tudo()


# ==============================================================================
# INICIALIZAÇÃO DE RECURSOS
# ==============================================================================

func _inicializar_ruidos() -> void:
	# Ruído de elevação do terreno (Simplex suave com fractal FBM)
	if noise_terreno == null:
		noise_terreno = FastNoiseLite.new()
	noise_terreno.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_terreno.seed = seed_terreno
	noise_terreno.frequency = frequencia_terreno
	noise_terreno.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_terreno.fractal_octaves = oitavas_terreno
	noise_terreno.fractal_lacunarity = 2.0
	noise_terreno.fractal_gain = 0.5

	# Ruído de civilização (determina zonas amplas de vilarejos)
	if noise_civilizacao == null:
		noise_civilizacao = FastNoiseLite.new()
	noise_civilizacao.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_civilizacao.seed = seed_civilizacao
	noise_civilizacao.frequency = frequencia_civilizacao
	noise_civilizacao.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_civilizacao.fractal_octaves = 2


func _inicializar_materiais_fallback() -> void:
	if _material_base_casa == null:
		_material_base_casa = StandardMaterial3D.new()
		_material_base_casa.albedo_color = Color(0.85, 0.78, 0.68) # Paredes claras rústicas
		_material_base_casa.roughness = 0.85
	
	if _material_telhado_casa == null:
		_material_telhado_casa = StandardMaterial3D.new()
		_material_telhado_casa.albedo_color = Color(0.72, 0.26, 0.16) # Telhas terracota
		_material_telhado_casa.roughness = 0.65


# ==============================================================================
# FUNÇÃO PRINCIPAL DE GERAÇÃO
# ==============================================================================

## Executa todo o pipeline de geração: malha do terreno, colisão e vilarejos
func gerar_tudo() -> void:
	_inicializar_ruidos()
	_inicializar_materiais_fallback()
	_preparar_hierarquia_nos()
	
	# 1. Gera a malha procedural via SurfaceTool com Vertex Colors
	var malha_terreno: ArrayMesh = _gerar_malha_terreno()
	if malha_terreno == null:
		return
	
	_terreno_mesh_instance.mesh = malha_terreno
	
	# 2. Configura material do terreno usando cores de vértice (vertex_color_use_as_albedo)
	var mat_terreno := StandardMaterial3D.new()
	mat_terreno.vertex_color_use_as_albedo = true
	mat_terreno.roughness = 0.95
	mat_terreno.specular = 0.1
	mat_terreno.cull_mode = BaseMaterial3D.CULL_BACK
	_terreno_mesh_instance.material_override = mat_terreno
	
	# 3. Criação atômica e robusta da colisão Trimesh (compatível com Jolt Physics e Godot Physics)
	_criar_colisao_trimesh_robusta(malha_terreno)
	
	# 4. Gera as vilas e casas em áreas planas adequadas
	_gerar_civilizacoes()
	
	# 5. Garante que o Player inicie sobre o solo sem cair no infinito
	if posicionar_player_no_chao and not Engine.is_editor_hint():
		_garantir_player_no_chao()


# ==============================================================================
# GESTÃO DA HIERARQUIA DE NÓS E COLISÃO
# ==============================================================================

func _preparar_hierarquia_nos() -> void:
	# Cria ou reaproveita o MeshInstance3D do terreno
	if _terreno_mesh_instance == null or not is_instance_valid(_terreno_mesh_instance):
		_terreno_mesh_instance = get_node_or_null("TerrenoMesh") as MeshInstance3D
		if _terreno_mesh_instance == null:
			_terreno_mesh_instance = MeshInstance3D.new()
			_terreno_mesh_instance.name = "TerrenoMesh"
			add_child(_terreno_mesh_instance)
			_definir_owner_seguro(_terreno_mesh_instance)

	# Cria ou limpa o container das casas / vilas
	if _vilas_container == null or not is_instance_valid(_vilas_container):
		_vilas_container = get_node_or_null("VilasContainer") as Node3D
		if _vilas_container == null:
			_vilas_container = Node3D.new()
			_vilas_container.name = "VilasContainer"
			add_child(_vilas_container)
			_definir_owner_seguro(_vilas_container)
	
	_limpar_vilas()


## Cria ou reconstrói o StaticBody3D com o ConcavePolygonShape3D devidamente inicializado
## antes de entrar na SceneTree. Isso é vital no Godot Jolt Physics para registrar a BVH.
func _criar_colisao_trimesh_robusta(malha: ArrayMesh) -> void:
	# Remove nó de colisão antigo se existir
	if _terreno_static_body != null and is_instance_valid(_terreno_static_body):
		if _terreno_static_body.get_parent() == self:
			remove_child(_terreno_static_body)
		_terreno_static_body.queue_free()
		_terreno_static_body = null
	
	var col_existente = get_node_or_null("TerrenoColisao")
	if col_existente != null:
		remove_child(col_existente)
		col_existente.queue_free()
	
	# Gera o ConcavePolygonShape3D a partir da geometria da malha
	var trimesh_shape: ConcavePolygonShape3D = malha.create_trimesh_shape()
	if trimesh_shape == null:
		push_error("Falha ao criar trimesh shape do terreno!")
		return
	
	# CRUCIAL NO JOLT PHYSICS E GODOT PHYSICS:
	# Ativa a detecção bidirecional para evitar que o CharacterBody atravesse o solo fino
	trimesh_shape.backface_collision = true
	
	_terreno_static_body = StaticBody3D.new()
	_terreno_static_body.name = "TerrenoColisao"
	_terreno_static_body.collision_layer = 1
	_terreno_static_body.collision_mask = 1
	
	_terreno_collision_shape = CollisionShape3D.new()
	_terreno_collision_shape.name = "CollisionShape3D"
	_terreno_collision_shape.shape = trimesh_shape
	
	# Adiciona o shape ao corpo ANTES de adicioná-lo à árvore, notificando o Jolt Physics
	_terreno_static_body.add_child(_terreno_collision_shape)
	add_child(_terreno_static_body)
	_definir_owner_seguro(_terreno_static_body)
	_definir_owner_seguro(_terreno_collision_shape)


func _garantir_player_no_chao() -> void:
	var target_player: CharacterBody3D = player
	if target_player == null and get_parent() != null:
		target_player = get_parent().find_child("Player", true, false) as CharacterBody3D
	if target_player == null and get_tree() != null and get_tree().root != null:
		target_player = get_tree().root.find_child("Player", true, false) as CharacterBody3D
	
	if target_player != null:
		var px: float = target_player.global_position.x
		var pz: float = target_player.global_position.z
		var h_terreno: float = obter_altura(px, pz)
		# Posiciona o jogador a 1.5m acima do relevo calculado na posição X, Z
		target_player.global_position.y = h_terreno + 1.5
		target_player.velocity = Vector3.ZERO


func _definir_owner_seguro(nodo: Node) -> void:
	if Engine.is_editor_hint() and is_inside_tree() and get_tree() != null and get_tree().edited_scene_root != null:
		nodo.owner = get_tree().edited_scene_root


func _limpar_vilas() -> void:
	if _vilas_container == null:
		return
	
	for filho in _vilas_container.get_children():
		_vilas_container.remove_child(filho)
		filho.queue_free()


# ==============================================================================
# TOPOGRAFIA E CÁLCULO MATEMÁTICO DE ALTURA
# ==============================================================================

## Calcula a altura em coordenadas de mundo (X, Z) aplicando a curva matemática
## de planícies suaves com montanhas isoladas e leitos de água.
func obter_altura(x: float, z: float) -> float:
	# Saída crua do FastNoiseLite (-1.0 a 1.0)
	var raw_n: float = noise_terreno.get_noise_2d(x, z)
	
	# REGRA 1: Valores negativos formam depressões suaves (leitos de água e bacias)
	if raw_n < 0.0:
		return raw_n * profundidade_maxima_agua
	
	# REGRA 2: Valores positivos baixos/médios (< limiar_montanhas) formam planícies
	# quase perfeitamente planas, com apenas uma sutilíssima ondulação natural.
	if raw_n < limiar_montanhas:
		var t_planicie: float = raw_n / limiar_montanhas
		return t_planicie * altura_maxima_planicie
	
	# REGRA 3: Valores altos (> limiar_montanhas, ex: > 0.45) disparam exponencialmente
	# formando picos de montanhas isolados e bem definidos.
	var t_montanha: float = (raw_n - limiar_montanhas) / (1.0 - limiar_montanhas)
	var fator_potencia: float = pow(t_montanha, expoente_montanhas)
	
	return altura_maxima_planicie + (fator_potencia * altura_maxima_montanhas)


# ==============================================================================
# SISTEMA DE CORES DE VÉRTICES (VERTEX COLORS)
# ==============================================================================

## Retorna a cor do vértice baseando-se estritamente nas faixas de altura
func obter_cor_vertice(altura: float) -> Color:
	# Região de Água / Leito de Areia (< 0.0m): Amarelo Areia
	if altura < 0.0:
		# Pequena transição na margem (-0.3m a 0.0m) para acabamento natural
		if altura >= -0.3:
			var t_areia: float = (altura + 0.3) / 0.3
			return cor_areia.lerp(cor_grama, t_areia * 0.3)
		return cor_areia
	
	# Planícies / Grama (entre 0.0m e início da subida das montanhas)
	if altura < altura_inicio_rocha:
		if altura <= 0.3:
			# Mistura sutil da orla da areia para grama completa
			var t_costa: float = altura / 0.3
			return cor_areia.lerp(cor_grama, t_costa)
		elif altura > (altura_inicio_rocha - 1.2):
			# Transição suave de grama para rocha conforme o terreno começa a inclinar
			var t_rocha: float = (altura - (altura_inicio_rocha - 1.2)) / 1.2
			return cor_grama.lerp(cor_rocha, t_rocha)
		return cor_grama
	
	# Montanhas Isoladas (Alturas Elevadas): Cinza Rocha com topo em Branco Neve
	if altura < altura_inicio_neve:
		# Faixa predominantemente rochosa, preparando para a linha de neve
		var intervalo_rocha: float = max(0.1, altura_inicio_neve - altura_inicio_rocha)
		var t_meio_montanha: float = (altura - altura_inicio_rocha) / intervalo_rocha
		return cor_rocha.lerp(cor_neve, clampf(t_meio_montanha * 0.25, 0.0, 0.25))
	
	# Picos mais altos: Branco Neve consolidado no topo
	var topo_max: float = max(altura_inicio_neve + 0.1, altura_maxima_planicie + altura_maxima_montanhas)
	var t_neve: float = (altura - altura_inicio_neve) / (topo_max - altura_inicio_neve)
	return cor_rocha.lerp(cor_neve, clampf(0.25 + t_neve * 0.75, 0.0, 1.0))


# ==============================================================================
# GERAÇÃO DA MALHA COM SURFACETOOL
# ==============================================================================

func _gerar_malha_terreno() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var num_x: int = tamanho_terreno.x
	var num_z: int = tamanho_terreno.y
	
	var offset_x: float = (float(num_x) * resolucao_vertice) * 0.5 if centralizar_terreno else 0.0
	var offset_z: float = (float(num_z) * resolucao_vertice) * 0.5 if centralizar_terreno else 0.0
	
	# Adiciona os vértices indexados à grade
	for iz in range(num_z + 1):
		var wz: float = (float(iz) * resolucao_vertice) - offset_z
		var v_ratio: float = float(iz) / float(num_z)
		
		for ix in range(num_x + 1):
			var wx: float = (float(ix) * resolucao_vertice) - offset_x
			var u_ratio: float = float(ix) / float(num_x)
			
			var wy: float = obter_altura(wx, wz)
			var cor_vert: Color = obter_cor_vertice(wy)
			
			st.set_color(cor_vert)
			st.set_uv(Vector2(u_ratio, v_ratio))
			st.add_vertex(Vector3(wx, wy, wz))
	
	# Gera os triângulos da grade (ordem voltada para CIMA no Godot)
	var largura_linha: int = num_x + 1
	for iz in range(num_z):
		for ix in range(num_x):
			var i00: int = (iz * largura_linha) + ix
			var i10: int = (iz * largura_linha) + (ix + 1)
			var i01: int = ((iz + 1) * largura_linha) + ix
			var i11: int = ((iz + 1) * largura_linha) + (ix + 1)
			
			# Primeiro triângulo do quad (face voltada para cima)
			st.add_index(i00)
			st.add_index(i10)
			st.add_index(i01)
			
			# Segundo triângulo do quad (face voltada para cima)
			st.add_index(i10)
			st.add_index(i11)
			st.add_index(i01)
	
	# Calcula normais e tangentes suaves automaticamente para iluminação perfeita
	st.generate_normals()
	st.generate_tangents()
	
	return st.commit()


# ==============================================================================
# GERAÇÃO DE CIVILIZAÇÕES / VILAREJOS
# ==============================================================================

## Varre o terreno em grade espaçada e testa as 3 condições para posicionar casas agrupadas
func _gerar_civilizacoes() -> void:
	var metade_x: float = (float(tamanho_terreno.x) * resolucao_vertice) * 0.5
	var metade_z: float = (float(tamanho_terreno.y) * resolucao_vertice) * 0.5
	
	# Limites seguros da amostragem (afastado das bordas do mapa)
	var margem: float = 8.0
	var min_x: float = -metade_x + margem if centralizar_terreno else margem
	var max_x: float = metade_x - margem if centralizar_terreno else (float(tamanho_terreno.x) * resolucao_vertice) - margem
	var min_z: float = -metade_z + margem if centralizar_terreno else margem
	var max_z: float = metade_z - margem if centralizar_terreno else (float(tamanho_terreno.y) * resolucao_vertice) - margem
	
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_civilizacao
	
	var z: float = min_z
	while z <= max_z:
		var x: float = min_x
		while x <= max_x:
			# Jitter pseudo-aleatório para que a distribuição pareça orgânica e não matricial
			var px: float = x + rng.randf_range(-jitter_casas, jitter_casas)
			var pz: float = z + rng.randf_range(-jitter_casas, jitter_casas)
			
			_avaliar_e_instanciar_casa(px, pz, rng)
			
			x += espacamento_grade_casas
		z += espacamento_grade_casas


## Avalia as 3 condições estritas antes de instanciar a casa
func _avaliar_e_instanciar_casa(px: float, pz: float, rng: RandomNumberGenerator) -> void:
	# CONDIÇÃO 3: Zona de Comunidade Ativa
	# O ruído de civilização com baixa frequência deve ultrapassar o limiar de vila
	var valor_civilizacao: float = noise_civilizacao.get_noise_2d(px, pz)
	if valor_civilizacao <= limiar_zona_vila:
		return
	
	# Controle de densidade natural dentro da vila (evita superlotação artificial)
	if rng.randf() > densidade_casas_na_vila:
		return
	
	var h_centro: float = obter_altura(px, pz)
	
	# CONDIÇÃO 1: Está na Planície (Verde)
	# Estritamente acima da areia da água (> 0.05m) e abaixo do início das montanhas
	var altura_minima_planicie: float = 0.05
	var altura_teto_planicie: float = altura_inicio_rocha - 0.5
	if h_centro <= altura_minima_planicie or h_centro >= altura_teto_planicie:
		return
	
	# CONDIÇÃO 2: Terreno Plano (Slope Check)
	# Amostra a elevação nos 4 eixos ao redor da fundação da casa (delta de 1.8 metros)
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
		return # Terreno muito inclinado/barranco; não constrói aqui
	
	# ==========================================================================
	# INSTANCIAÇÃO DA CASA
	# ==========================================================================
	var instancia_casa: Node3D
	
	if cena_casa != null:
		instancia_casa = cena_casa.instantiate() as Node3D
	else:
		# Fallback procedural: Casa completa com paredes (Box), telhado (Prism) e colisão
		instancia_casa = _criar_casa_fallback_procedural(rng)
	
	if instancia_casa == null:
		return
	
	# Posiciona sobre o terreno na altura calculada
	instancia_casa.position = Vector3(px, h_centro, pz)
	
	# Rotação suave aleatória para dar personalidade única a cada construção
	instancia_casa.rotation.y = rng.randf_range(0.0, TAU)
	
	_vilas_container.add_child(instancia_casa)
	_definir_owner_seguro(instancia_casa)


# ==============================================================================
# FALLBACK PROCEDURAL DA CASA (BOX + PRISM + COLISÃO)
# ==============================================================================

## Gera uma casa estilizada procedural com base cúbica e telhado prismático
func _criar_casa_fallback_procedural(rng: RandomNumberGenerator) -> Node3D:
	var raiz_casa := StaticBody3D.new()
	raiz_casa.name = "CasaProcedural"
	
	# Pequena variação de escala para diversificar o vilarejo
	var escala_var: float = rng.randf_range(0.85, 1.15)
	var largura: float = 3.2 * escala_var
	var altura_parede: float = 2.4 * escala_var
	var profundidade: float = 3.0 * escala_var
	var altura_telhado: float = 1.4 * escala_var
	
	# 1. Base / Paredes (BoxMesh)
	var mesh_base := MeshInstance3D.new()
	mesh_base.name = "Paredes"
	var box := BoxMesh.new()
	box.size = Vector3(largura, altura_parede, profundidade)
	mesh_base.mesh = box
	mesh_base.material_override = _material_base_casa
	# Eleva a base para que a fundação apoie perfeitamente no chão Y=0
	mesh_base.position = Vector3(0.0, altura_parede * 0.5, 0.0)
	raiz_casa.add_child(mesh_base)
	
	# 2. Telhado (PrismMesh)
	var mesh_telhado := MeshInstance3D.new()
	mesh_telhado.name = "Telhado"
	var prisma := PrismMesh.new()
	prisma.size = Vector3(largura * 1.1, altura_telhado, profundidade * 1.08)
	mesh_telhado.mesh = prisma
	mesh_telhado.material_override = _material_telhado_casa
	# O prisma do Godot tem o cume no topo; orientamos com rotação padrão
	mesh_telhado.position = Vector3(0.0, altura_parede + (altura_telhado * 0.5), 0.0)
	raiz_casa.add_child(mesh_telhado)
	
	# 3. Colisor para que o jogador / câmera colida com a casa
	var colisor := CollisionShape3D.new()
	colisor.name = "CollisionShape3D"
	var shape_box := BoxShape3D.new()
	var altura_total: float = altura_parede + altura_telhado
	shape_box.size = Vector3(largura, altura_total, profundidade)
	colisor.shape = shape_box
	colisor.position = Vector3(0.0, altura_total * 0.5, 0.0)
	raiz_casa.add_child(colisor)
	
	return raiz_casa
