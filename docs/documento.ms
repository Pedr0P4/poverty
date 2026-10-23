.fam H
.nr PS 10p
.nr VS 14p
.nr PO 0.6i
.nr LL 7.0i
.nr HM 0.6i
.nr FM 0.6i
.TL
Sistema de Inventário e Hotbar no Godot 4
.AU
Antigravity (Senior Game Developer)
.AI
Projeto Poverty - Guia Técnico e Referência de Métodos

.NH 1
Guia Técnico Completo de Arquitetura, Implementação e Referência de Métodos
.PP
\fBAutor:\fR Antigravity (Senior Game Developer)
.br
\fBProjeto:\fR Poverty (Godot 4 - 3D)
.br
\fBPlataforma de Leitura:\fR Otimizado para leitura em Smartphones e Desktop
.br
.sp 0.5

.NH 1
1. Visão Geral e Filosofia de Design
.PP
No desenvolvimento profissional de jogos com o Godot 4, a separação estrita entre \fBModelo de Dados (Model)\fR e \fBInterface do Usuário (View/Controller)\fR é indispensável. Misturar variáveis de contagem e referências de itens diretamente dentro de botões ou contêineres visuais resulta em problemas graves de dessincronização, bugs ao empilhar itens e código frágil.
.br

.NH 2
Os Pilares do Sistema:
.PP
.IP \(bu 2
**Dados Imutáveis e Compartilhados via Resource (ItemData):**
Os tipos de itens (ex: Rifle, Munição, Kit Médico, Chave) são recursos salvos no disco (\fB.tres\fR). Eles armazenam propriedades estáticas como nome, ícone, cor e regras de agrupamento.
.br
.IP \(bu 2
**Estado Efêmero em Memória via RefCounted (InventorySlotData):**
Cada slot no inventário ou na hotbar guarda apenas uma instância leve de dados com a referência ao item e a quantidade atual.
.br
.IP \(bu 2
**Componentização Modular da UI (InventorySlotUI):**
Cada célula visual é independente, cuidando do desenho de bordas, badges de quantidade, ícones e disparando eventos de clique para o pai.
.br
.IP \(bu 2
**Gerenciador Centralizado de Estado (InventoryUI):**
Orquestra as transições visuais (abrir/fechar com tecla E), atalhos de mouse (rolagem da hotbar, clique esquerdo, clique direito e Shift+Clique), e o cursor flutuante.
.br
.IP \(bu 2
**Integração Física e de Gameplay:**
O jogador pode continuar andando com WASD enquanto o inventário está aberto, porém a mira da câmera e os disparos de tiro são congelados para permitir interação com o cursor do mouse. A arma 3D equipada na mão reage instantaneamente ao slot selecionado na Hotbar.
.br
.sp 0.5

.NH 1
2. Requisitos Atendidos em Detalhes
.PP

.NH 2
Grade de 6 Colunas por 3 Linhas (18 Slots)
.PP
O inventário principal é formatado em um \fBGridContainer\fR com 6 colunas, totalizando 18 espaços para armazenar itens.
.br

.NH 2
Hotbar de 6 Slots e Foco com Rolagem do Mouse
.PP
A Hotbar possui exatamente 6 posições, alinhando-se com a largura das 6 colunas do inventário. A rotação do scroll do mouse (\fBWHEEL_UP\fR e \fBWHEEL_DOWN\fR) altera o slot focado de 0 a 5 com wrap-around contínuo (usando a função \fBposmod\fR). O slot ativo recebe uma moldura dourada destacada.
.br

.NH 2
A Mágica da Transição da Hotbar
.PP
.IP \(bu 2
**Inventário Fechado:** A Hotbar de HUD fica ancorada na parte inferior da tela.
.IP \(bu 2
**Inventário Aberto (Tecla E):** A Hotbar inferior desaparece completamente e surge acoplada logo abaixo das 3 linhas e 6 colunas do inventário, aproximando os slots para facilitar a transferência e o arrasto de itens.

.NH 2
Controle de Agrupamento (`can_stack` e `max_stack`)
.PP
Cada item possui o booleano \fBcan_stack\fR. Se for falso, o item não se agrupa (ex: Rifle e Chave). Se for verdadeiro, o limite padrão é acumular até 20 unidades sozinho (ex: Munição e Kit Médico).
.br

.NH 2
Clique Direito (Extrair 1 Unidade)
.PP
Ao clicar com o botão direito sobre um slot com itens agrupados, exatamente 1 unidade é transferida para o cursor. Cliques com o botão direito adicionais sobre o mesmo item no slot somam +1 ao cursor até atingir o limite de 20. Se o cursor já tiver itens e o clique direito for em um slot vazio, 1 unidade é depositada nele.
.br

.NH 2
Atalhos de Shift (`Shift + Clique`)
.PP
.IP \(bu 2
**Clicar na Hotbar segurando Shift:** O item é movido automaticamente para o inventário.
.IP \(bu 2
**Clicar no Inventário segurando Shift:** O item é movido automaticamente para a hotbar.
.IP \(bu 2
**Lógica de Preenchimento Inteligente:** O algoritmo tenta primeiro completar pilhas incompletas existentes do mesmo item no destino (até 20) e depois procura o primeiro slot totalmente livre em ordem. Se não houver espaço, o comando não faz nada.

.NH 2
Suporte Híbrido: Minecraft (Clique-a-Clique) + Drag & Drop
.PP
O jogador pode tanto clicar no slot de origem, mover o mouse e clicar no slot de destino, quanto simplesmente segurar o botão esquerdo e arrastar até o outro slot. Ambos os fluxos funcionam nativamente.
.br
.sp 0.5

.NH 1
3. Explicação dos Scripts Criados e Modificados
.PP

.NH 2
3.1. `script/item_data.gd` (`ItemData`)
.PP
Estende \fBResource\fR. Representa o "molde" de cada item.
.br
.IP \(bu 2
id: Identificador textual único do item.
.IP \(bu 2
item_name: Nome exibido na interface.
.IP \(bu 2
icon: Textura gráfica exibida nos slots e no cursor flutuante.
.IP \(bu 2
icon_modulate: Multiplicador de cor para o ícone.
.IP \(bu 2
can_stack: Booleano que define se pode ser agrupado.
.IP \(bu 2
max_stack: Limite máximo de empilhamento (padrão 20).
.IP \(bu 2
is_rifle: Identificador para acoplamento do rifle 3D na mão do jogador.

.NH 2
3.2. `script/inventory_slot_data.gd` (`InventorySlotData`)
.PP
Estende \fBRefCounted\fR. Representa a informação armazenada em cada posição de inventário ou no cursor.
.br
.IP \(bu 2
item: Referência ao ItemData presente no slot.
.IP \(bu 2
quantity: Quantidade numérica de unidades presentes.

.NH 2
3.3. `script/inventory_slot_ui.gd` (`InventorySlotUI`)
.PP
Estende \fBPanelContainer\fR. Representa visualmente um quadradinho na tela.
.br
.IP \(bu 2
Renderiza 3 estilos visuais com StyleBoxFlat (Normal, Hover e Focused).
.IP \(bu 2
Controla visibilidade de ícone, nome e número de quantidade (ocultando quando quantidade for 1 ou vazio).
.IP \(bu 2
Detecta eventos do mouse e emite o sinal slot_pressed.

.NH 2
3.4. `script/inventory_ui.gd` (`InventoryUI`)
.PP
Estende \fBControl\fR. O maestro da interface.
.br
.IP \(bu 2
Contém os arrays de dados inventory_slots (18 posições) e hotbar_slots (6 posições).
.IP \(bu 2
Mantém o objeto held_slot que representa o item preso ao cursor.
.IP \(bu 2
Processa inputs da tecla E (inventory), rolagem do mouse e soltura de cliques.
.IP \(bu 2
Controla a visibilidade e o posicionamento do cursor flutuante.

.NH 2
3.5. `script/player.gd` (Integração)
.PP
.IP \(bu 2
Escuta os sinais equipped_item_changed e inventory_toggled.
.IP \(bu 2
Quando o inventário abre, libera o ponteiro do mouse (MOUSE_MODE_VISIBLE), oculta a mira (ColorRect) e trava o giro da visão no _input, mantendo a física de caminhada no _physics_process.
.IP \(bu 2
Exibe ou esconde o nó 3D do Rifle dependendo se o slot selecionado na Hotbar contém o item do Rifle.

.NH 2
3.6. `script/camera.gd` (Segurança de Disparo)
.PP
.IP \(bu 2
Verifica se o inventário está fechado, se o mouse está capturado e se a arma está visível antes de chamar o método shoot().
.sp 0.5

.NH 1
4. ADENDO ESPECIAL: Dicionário Detalhado de CADA Método Criado
.PP
Abaixo encontra-se a lista completa e a explicação técnica detalhada de cada método criado no sistema.
.br

.NH 2
4.1. Classe `ItemData` (`script/item_data.gd`)
.PP
.IP \(bu 2
get_effective_max_stack() -> int:
Retorna o valor efetivo de empilhamento. Se \fBcan_stack\fR for falso, retorna obrigatoriamente \fB1\fR. Se for verdadeiro, retorna o valor de \fBmax_stack\fR (padrão 20). Essa guarda previne que itens não agrupáveis recebam mais de uma unidade por engano.
.br
.sp 0.5

.NH 2
4.2. Classe `InventorySlotData` (`script/inventory_slot_data.gd`)
.PP
.IP \(bu 2
_init(p_item: ItemData = null, p_quantity: int = 0) -> void:
Construtor da classe. Permite inicializar o slot já com um item e quantidade definidos ou vazio por padrão.
.br
.IP \(bu 2
is_empty() -> bool:
Verifica se o slot está desocupado. Retorna \fBtrue\fR se \fBitem == null\fR ou se \fBquantity <= 0\fR.
.br
.IP \(bu 2
clear() -> void:
Esvazia o slot, setando \fBitem = null\fR e \fBquantity = 0\fR.
.br
.IP \(bu 2
set_data(p_item: ItemData, p_quantity: int) -> void:
Define com segurança os dados do slot. Caso o item passado seja nulo ou a quantidade seja menor ou igual a 0, chama automaticamente \fBclear()\fR.
.br
.IP \(bu 2
copy_from(other: InventorySlotData) -> void:
Clona os dados de outro slot para este, copiando a referência do item e a quantidade. Se o outro slot for nulo ou vazio, limpa este slot.
.br
.IP \(bu 2
can_stack_with(other_item: ItemData) -> bool:
Retorna \fBtrue\fR se este slot contiver o mesmo item passado, se esse item permitir agrupamento (\fBcan_stack == true\fR) e se a quantidade atual ainda não tiver atingido o limite máximo de empilhamento (\fBquantity < max_stack\fR).
.br
.sp 0.5

.NH 2
4.3. Classe `InventorySlotUI` (`script/inventory_slot_ui.gd`)
.PP
.IP \(bu 2
_ready() -> void:
Método padrão do ciclo de vida do Godot. Configura os estilos visuais de caixa (\fB_setup_styles\fR), conecta os sinais de entrada e saída do mouse (\fBmouse_entered\fR e \fBmouse_exited\fR) e aplica o estilo inicial.
.br
.IP \(bu 2
_setup_styles() -> void:
Cria programaticamente 3 instâncias de \fBStyleBoxFlat\fR:
.br
.IP \(bu 2
Estilo normal: cinza escuro translúcido com borda suave de 2px.
.IP \(bu 2
Estilo hover: fundo e borda ligeiramente iluminados ao passar o mouse.
.IP \(bu 2
Estilo focado: fundo dourado escuro com **borda amarela brilhante de 3px** para indicar o slot ativo da Hotbar.
.IP \(bu 2
update_slot(data: InventorySlotData, focused: bool = false) -> void:
Recebe os dados do slot correspondente e atualiza a apresentação gráfica. Se estiver vazio, oculta os nós filhos de texto e textura. Se possuir item, preenche a textura do ícone, cor de modulação, nome do item no topo e contador de quantidade no canto inferior (apenas se a quantidade for maior que 1).
.br
.IP \(bu 2
_update_style() -> void:
Aplica no tema do \fBPanelContainer\fR o \fBStyleBoxFlat\fR correto dependendo dos estados booleanos \fBis_focused\fR e \fBis_hovered\fR.
.br
.IP \(bu 2
_on_mouse_entered() -> void:
Callback do sinal disparado quando o cursor do mouse entra na área retangular deste slot. Ativa a flag \fBis_hovered = true\fR e redesenha o estilo.
.br
.IP \(bu 2
_on_mouse_exited() -> void:
Callback do sinal disparado quando o cursor do mouse sai do retângulo do slot. Desativa a flag \fBis_hovered = false\fR e redesenha o estilo.
.br
.IP \(bu 2
_gui_input(event: InputEvent) -> void:
Intercepta os eventos de interface gráfica direcionados ao slot. Se detectar um clique pressionado com botão esquerdo ou direito, emite o sinal personalizado \fBslot_pressed\fR com o índice do slot, se é hotbar ou inventário, qual botão foi clicado e se o Shift estava pressionado.
.br
.sp 0.5

.NH 2
4.4. Classe `InventoryUI` (`script/inventory_ui.gd`)
.PP
.IP \(bu 2
_ready() -> void:
Ponto de partida do controlador de UI. Inicializa os arrays de dados (\fB_init_data\fR), gera os nós de interface instanciando a cena do slot (\fB_build_ui_slots\fR), popula os itens de demonstração (\fB_populate_starter_items\fR) e define o estado fechado inicial (\fB_set_open_state(false)\fR).
.br
.IP \(bu 2
_process(_delta: float) -> void:
Atualiza a posição do nó \fBCursorItem\fR a cada frame renderizado para que ele siga com perfeição as coordenadas globais do mouse (\fBget_global_mouse_position()\fR) quando houver um item preso ao cursor.
.br
.IP \(bu 2
_input(event: InputEvent) -> void:
Escuta inputs globais:
.br
.IP \(bu 2
Abertura/fechamento com a tecla E (event.is_action_pressed("inventory")).
.IP \(bu 2
Rolagem do scroll do mouse para cima e para baixo para trocar o slot focado na hotbar.
.IP \(bu 2
Soltura do botão esquerdo do mouse para completar ações de arrastar e soltar (Drag & Drop).
.IP \(bu 2
_init_data() -> void:
Preenche os arrays \fBinventory_slots\fR com 18 instâncias limpas de \fBInventorySlotData\fR e \fBhotbar_slots\fR com 6 instâncias limpas.
.br
.IP \(bu 2
_build_ui_slots() -> void:
Configura as colunas das grades (6 colunas) e instancia dinamicamente 18 nós \fBInventorySlotUI\fR para o inventário, 6 para a hotbar no modal e 6 para a hotbar de HUD, conectando o sinal \fBslot_pressed\fR de cada um ao método centralizador \fB_on_slot_pressed\fR.
.br
.IP \(bu 2
_populate_starter_items() -> void:
Adiciona itens de demonstração para testes imediatos (Rifle e Munição na Hotbar, e kits médicos, munição extra e chave no inventário).
.br
.IP \(bu 2
toggle_inventory() -> void:
Inverte o estado atual do inventário (se aberto, fecha; se fechado, abre), chamando \fB_set_open_state\fR.
.br
.IP \(bu 2
_set_open_state(open: bool) -> void:
Aplica as transformações visuais e de contexto do jogo:
.br
.IP \(bu 2
Se for fechar e houver item no cursor, devolve o item para o inventário com _return_held_item_on_close().
.IP \(bu 2
Alterna a visibilidade da Hotbar inferior (hud_hotbar_panel.visible = not open) e da janela do inventário (inventory_modal.visible = open).
.IP \(bu 2
Altera o modo do mouse entre capturado e visível (Input.MOUSE_MODE_VISIBLE / Input.MOUSE_MODE_CAPTURED).
.IP \(bu 2
Atualiza todos os slots e emite o sinal inventory_toggled.
.IP \(bu 2
_change_hotbar_focus(step: int) -> void:
Altera o índice \fBselected_hotbar_index\fR somando o passo (\fB+1\fR ou \fB-1\fR) e aplicando a função matemática \fBposmod\fR com \fBHOTBAR_SIZE\fR (6). Atualiza os slots e emite \fBequipped_item_changed\fR.
.br
.IP \(bu 2
get_selected_hotbar_item() -> ItemData:
Função de consulta rápida. Retorna o \fBItemData\fR presente no slot ativo da Hotbar ou \fBnull\fR se o slot estiver vazio.
.br
.IP \(bu 2
_on_slot_pressed(slot_index: int, is_hotbar: bool, button_index: int, shift_pressed: bool) -> void:
Direcionador principal de cliques:
.br
.IP \(bu 2
Se o inventário estiver fechado, ignora.
.IP \(bu 2
Se shift_pressed == true, chama _handle_shift_click.
.IP \(bu 2
Se botão esquerdo, chama _handle_left_click.
.IP \(bu 2
Se botão direito, chama _handle_right_click.
.IP \(bu 2
Ao final, chama _refresh_all_ui().
.IP \(bu 2
_handle_left_click(target_slot: InventorySlotData, slot_index: int, is_hotbar: bool) -> void:
Trata o clique com botão esquerdo:
.br
.IP \(bu 2
Se o cursor estiver vazio e o slot tiver item: transfere todo o conteúdo para o cursor e inicia a marcação de arrasto (_is_dragging_left = true).
.IP \(bu 2
Se o cursor já tiver item: chama _place_or_swap_held_into_slot(target_slot).
.IP \(bu 2
_handle_mouse_left_release() -> void:
Executado quando o botão esquerdo é solto. Varre os retângulos globais dos slots visuais com \fBhas_point(mouse_pos)\fR. Se o jogador tiver soltado sobre outro slot diferente do original, deposita ou troca o item naquele slot imediatamente, concretizando o Drag & Drop.
.br
.IP \(bu 2
_place_or_swap_held_into_slot(target_slot: InventorySlotData) -> void:
Lógica matemática de transferência:
.br
.IP \(bu 2
Se o slot destino estiver vazio: coloca tudo e limpa o cursor.
.IP \(bu 2
Se tiver o mesmo item e for agrupável: calcula o espaço até o limite de 20 e transfere o que couber. Se atingir 20, a sobra continua no cursor.
.IP \(bu 2
Se os itens forem diferentes ou não agrupáveis: faz a troca mútua (swap).
.IP \(bu 2
_handle_right_click(target_slot: InventorySlotData) -> void:
Lógica do botão direito:
.br
.IP \(bu 2
Se o slot clicado tiver item e o cursor estiver vazio: tira exatamente 1 unidade para o cursor.
.IP \(bu 2
Se o cursor já tiver o mesmo item agrupável e < 20: retira mais +1 unidade do slot e soma ao cursor.
.IP \(bu 2
Se o slot clicado for vazio e o cursor tiver itens: deposita 1 unidade do cursor no slot.
.IP \(bu 2
_handle_shift_click(source_slot: InventorySlotData, from_hotbar: bool) -> void:
Lógica de transferência expressa:
.br
.IP \(bu 2
Define o array destino (se veio da hotbar, vai para inventory_slots; se veio do inventário, vai para hotbar_slots).
.IP \(bu 2
Passo 1: Se agrupável, procura pilhas existentes com o mesmo item no destino e completa até 20.
.IP \(bu 2
Passo 2: Se ainda sobrar unidades, procura o primeiro slot com is_empty() == true e coloca o item lá.
.IP \(bu 2
_return_held_item_on_close() -> void:
Garantia de segurança: se o jogador fechar o inventário segurando um item no cursor, devolve para o slot de origem ou usa a lógica de shift-click para guardá-lo.
.br
.IP \(bu 2
_refresh_all_ui() -> void:
Sincroniza todos os 18 nós do inventário, os 6 da hotbar modal e os 6 da hotbar HUD com seus respectivos dados, atualiza a visibilidade e o texto do cursor flutuante e emite \fBequipped_item_changed\fR.
.br
.sp 0.5

.NH 2
4.5. Métodos Integrados em `Player` (`script/player.gd`)
.PP
.IP \(bu 2
is_inventory_open() -> bool:
Retorna se o inventário está atualmente aberto consultando \fBinventory_ui.is_open\fR.
.br
.IP \(bu 2
_on_equipped_item_changed(item: ItemData) -> void:
Receptor do sinal da hotbar. Se \fBitem != null and item.is_rifle\fR, torna o nó 3D do Rifle visível na mão; caso contrário, esconde o rifle.
.br
.IP \(bu 2
_on_inventory_toggled(open: bool) -> void:
Receptor do sinal de alternância do inventário. Oculta a mira central (\fBcrosshair.visible = not open\fR) quando o inventário está aberto.
.br