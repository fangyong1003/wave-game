class_name SurvivalUI
extends CanvasLayer
signal action(name: String, value: Variant)
const Items = preload("res://scripts/survival/items.gd")
const INK := Color("d4d8d0")
const MUTED := Color("98a9a4")
const AMBER := Color("c99a53")
const RED := Color("aa6253")
const GREEN := Color("a7b9a0")
var root: Control
var menu: Control
var menu_body: VBoxContainer
var hud: Control
var overlay: Control
var content: VBoxContainer
var view := "menu"
var toast_label: Label
var toast_time := 0.0
var location: Label
var objective: Label
var hp_label: Label
var stamina_label: Label
var hp_bar: ProgressBar
var stamina_bar: ProgressBar
var xp_bar: ProgressBar
var level_label: Label
var status_label: Label
var reticle: Label
var hit_label: Label
var hit_time := 0.0
var progress: ProgressBar
var search_spinner: SurvivalSearchSpinner
var weapon_label: Label
var enemy_bar: ProgressBar
var damage_layer: ColorRect
var damage_time := 0.0
var title_font: SystemFont
var body_font: SystemFont
var mono_font: SystemFont
var list_box: VBoxContainer
var equipment_box: VBoxContainer
var stats_box: VBoxContainer
var panel_status: Label
var panel_capacity: Label
var details: Label
var filter := "全部"
var current_state: SurvivalState
var binding_action := ""
var binding_button: Button
var binding_buttons := {}
var settings_origin := "menu"
var search_panel: PanelContainer
var search_content: VBoxContainer
var search_rows: VBoxContainer
var search_capacity: Label
var search_take_all: Button

func _ready() -> void:
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_font = SystemFont.new()
	body_font.font_names = PackedStringArray(["PingFang SC","Noto Sans CJK SC","Microsoft YaHei","sans-serif"])
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["Songti SC","Noto Serif CJK SC","serif"])
	mono_font = SystemFont.new()
	mono_font.font_names = PackedStringArray(["Menlo","Consolas","monospace"])
	var theme := Theme.new()
	theme.default_font = body_font
	theme.default_font_size = 17
	theme.set_color("font_color","Label",INK)
	root.theme = theme
	menu = full(root)
	var veil := ColorRect.new()
	menu.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){COLOR=vec4(0.033,0.055,0.055,mix(.97,.05,smoothstep(.05,.85,UV.x)));}"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	veil.material = mat
	menu_body = VBoxContainer.new()
	menu_body.position = Vector2(80,72)
	menu_body.size = Vector2(465,720)
	menu_body.add_theme_constant_override("separation",18)
	menu.add_child(menu_body)
	build_hud()
	overlay = full(root)
	var shade := ColorRect.new()
	shade.color = Color(.015,.025,.025,.82)
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -654
	panel.offset_right = 654
	panel.offset_top = -407
	panel.offset_bottom = 407
	panel.add_theme_stylebox_override("panel",style(Color("202d2d"),Color("5e7067"),26))
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation",15)
	panel.add_child(content)
	overlay.hide()
	search_panel=PanelContainer.new();root.add_child(search_panel)
	anchor(search_panel,Control.PRESET_TOP_RIGHT,-530,-30,165,715)
	search_panel.add_theme_stylebox_override("panel",style(Color(.08,.13,.13,.96),Color("5e7067"),22))
	search_content=VBoxContainer.new();search_content.add_theme_constant_override("separation",16);search_panel.add_child(search_content)
	search_panel.hide()
	# Notifications sit above inventory and safehouse panels too.
	toast_label = label(root,"",19,INK)
	anchor(toast_label,Control.PRESET_CENTER_TOP,-485,485,79,134)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	toast_label.add_theme_constant_override("shadow_offset_y",2)
	toast_label.add_theme_color_override("font_outline_color",Color(.025,.035,.035,.8))
	toast_label.add_theme_constant_override("outline_size",4)
	toast_label.hide()

func style(color: Color, border: Color = Color.TRANSPARENT, padding: float = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s
func full(parent: Control) -> Control:
	var c := Control.new()
	parent.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c
func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
func label(parent: Node, text: String, size: int = 17, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
func button(parent: Node, text: String, callback: Callable, width: float = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width,42)
	b.add_theme_stylebox_override("normal",style(Color("2b3a37"),Color("4e6058")))
	b.add_theme_stylebox_override("hover",style(Color("405045"),AMBER))
	b.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,AMBER))
	b.add_theme_stylebox_override("pressed",style(Color("56604c"),AMBER))
	b.add_theme_stylebox_override("disabled",style(Color("25322f"),Color("37443d")))
	b.add_theme_color_override("font_color",INK)
	b.add_theme_color_override("font_disabled_color",Color("6d7b73"))
	parent.add_child(b)
	b.pressed.connect(callback)
	return b
func anchor(node: Control, preset: int, left: float, right: float, top: float, bottom: float) -> void:
	node.set_anchors_and_offsets_preset(preset)
	node.offset_left = left
	node.offset_right = right
	node.offset_top = top
	node.offset_bottom = bottom
func bar(parent: Control, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 100
	b.add_theme_stylebox_override("background",style(Color(.04,.065,.06,.85),Color.TRANSPARENT,0))
	b.add_theme_stylebox_override("fill",style(color,Color.TRANSPARENT,0))
	parent.add_child(b)
	return b
func heading(parent: Node, text: String, size: int = 30) -> Label:
	var l := label(parent,text,size)
	l.add_theme_font_override("font",title_font)
	return l

func build_hud() -> void:
	hud = full(root)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_layer = ColorRect.new()
	hud.add_child(damage_layer)
	damage_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float amount=0.; void fragment(){float edge=smoothstep(.24,.69,length(UV-vec2(.5)));COLOR=vec4(.42,.08,.045,edge*amount);}"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	damage_layer.material = mat
	location = label(hud,"南楼 / 03 层",18)
	location.position = Vector2(34,26)
	objective = label(hud,"背包 0 / 6",16,MUTED)
	objective.position = Vector2(34,56)
	level_label = label(hud,"LV 1",19,AMBER)
	level_label.add_theme_font_override("font",mono_font)
	anchor(level_label,Control.PRESET_TOP_RIGHT,-265,-35,27,55)
	xp_bar = bar(hud,AMBER)
	anchor(xp_bar,Control.PRESET_TOP_RIGHT,-265,-35,61,65)
	hp_label = label(hud,"生命 100 / 100",18)
	anchor(hp_label,Control.PRESET_BOTTOM_LEFT,35,330,-153,-124)
	hp_bar = bar(hud,RED)
	anchor(hp_bar,Control.PRESET_BOTTOM_LEFT,35,300,-119,-111)
	stamina_label = label(hud,"体力 100 / 100",16,MUTED)
	anchor(stamina_label,Control.PRESET_BOTTOM_LEFT,35,330,-102,-75)
	stamina_bar = bar(hud,GREEN)
	anchor(stamina_bar,Control.PRESET_BOTTOM_LEFT,35,300,-72,-67)
	status_label = label(hud,"",14,AMBER)
	anchor(status_label,Control.PRESET_BOTTOM_LEFT,35,500,-49,-17)
	weapon_label=label(hud,"",17,INK)
	anchor(weapon_label,Control.PRESET_BOTTOM_RIGHT,-360,-32,-143,-72)
	weapon_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	reticle = label(hud,"·",29)
	anchor(reticle,Control.PRESET_CENTER,-6,10,-23,23)
	hit_label = label(hud,"×",28,INK)
	anchor(hit_label,Control.PRESET_CENTER,-10,18,-23,23)
	hit_label.hide()
	for l in [location,objective,level_label,hp_label,stamina_label,status_label,weapon_label]:
		l.add_theme_color_override("font_shadow_color",Color.BLACK)
		l.add_theme_constant_override("shadow_offset_y",2)
		l.add_theme_color_override("font_outline_color",Color(.025,.035,.035,.8))
		l.add_theme_constant_override("outline_size",4)
	progress = bar(hud,AMBER)
	progress.max_value = 1
	anchor(progress,Control.PRESET_CENTER,-70,70,46,50)
	progress.hide()
	search_spinner=preload("res://scripts/survival/search_spinner.gd").new();hud.add_child(search_spinner)
	anchor(search_spinner,Control.PRESET_CENTER,-31,31,-31,31);search_spinner.hide()
	enemy_bar = bar(hud,RED)
	anchor(enemy_bar,Control.PRESET_CENTER,-63,63,-109,-105)
	enemy_bar.hide()
	hud.hide()

func show_menu(has_save: bool, pause: bool = false) -> void:
	search_panel.hide()
	view = "pause" if pause else "menu"
	menu.show(); hud.hide(); overlay.hide()
	clear(menu_body)
	label(menu_body,"断供第七天 / 南楼",17,AMBER)
	heading(menu_body,"现场暂停" if pause else "南楼\n求生",74)
	label(menu_body,"当前现场已保存。" if pause else "带回饮水。\n带回装备。\n活着回来。",22,MUTED)
	var spacer := Control.new();spacer.custom_minimum_size.y=20;menu_body.add_child(spacer)
	if pause:
		button(menu_body,"返回现场",func(): action.emit("resume",null)).grab_focus()
	else:
		if has_save: button(menu_body,"继续生存",func(): action.emit("continue",null)).grab_focus()
		button(menu_body,"重新开始" if has_save else "开始生存",func():
			if has_save: confirm_new()
			else: action.emit("new",null))
	button(menu_body,"视角、打击反馈与操作",func(): action.emit("settings",null))
	if not pause: button(menu_body,"制作与资源署名",func(): action.emit("credits",null))
	button(menu_body,"退出游戏",func(): action.emit("quit",null))
	label(menu_body,"单人可玩原型 · 搜刮 / 近战 / 成长",14,MUTED)
func confirm_new() -> void:
	clear(menu_body)
	heading(menu_body,"重新开始",48)
	label(menu_body,"将替换当前求生进度与角色成长。\n旧维修存档仍独立保留。",19,MUTED)
	button(menu_body,"保留进度，返回",func(): show_menu(true))
	button(menu_body,"开始新的生存档",func(): action.emit("new",null))
func show_game() -> void:
	view = "game"
	search_panel.hide();reticle.show()
	menu.hide(); overlay.hide(); hud.show()
func show_transition(caption: String) -> void:
	view="loading";search_panel.hide();hud.hide();overlay.hide();menu.show();clear(menu_body)
	label(menu_body,"南楼 / 南街",17,AMBER)
	heading(menu_body,caption,44)
	label(menu_body,"穿过楼梯间，正在载入区域…",20,MUTED)
	var spinner:=SurvivalSearchSpinner.new();spinner.custom_minimum_size=Vector2(110,110)
	menu_body.add_child(spinner);spinner.begin();spinner.percent.hide()

func show_search(source: SurvivalSearchable,state: SurvivalState) -> void:
	show_game();view="search";search_panel.show();reticle.hide()
	clear(search_content)
	var title_row:=HBoxContainer.new();search_content.add_child(title_row)
	heading(title_row,source.caption,27).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(title_row,"关闭",func(): action.emit("search_close",null),66)
	label(search_content,"检索完成",15,AMBER)
	search_capacity=label(search_content,"",17,MUTED)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(444,254);search_content.add_child(scroll)
	search_rows=VBoxContainer.new();search_rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;search_rows.add_theme_constant_override("separation",12);scroll.add_child(search_rows)
	search_take_all=button(search_content,"全部拿取",func(): action.emit("search_all",null))
	refresh_search(source,state)
func refresh_search(source: SurvivalSearchable,state: SurvivalState) -> void:
	if view!="search" or not is_instance_valid(search_rows): return
	search_capacity.text="背包 %d / %d 格     ·     剩余 %d 件" % [state.inventory.size(),state.capacity(),source.contents.size()]
	search_take_all.disabled=source.contents.is_empty() or state.inventory.size()>=state.capacity()
	clear(search_rows)
	if source.contents.is_empty():
		heading(search_rows,"已经搜空",26)
	for item in source.contents:
		var row:=HBoxContainer.new();search_rows.add_child(row)
		var names:=VBoxContainer.new();names.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(names)
		label(names,Items.caption(item),19)
		label(names,str(Items.definition(item.id).category),14,MUTED)
		var b:=button(row,"拿取",func(): action.emit("search_take",item.uid),83)
		b.disabled=state.inventory.size()>=state.capacity()
		b.tooltip_text=str(Items.definition(item.id).note)
func show_credits() -> void:
	view="credits";search_panel.hide();menu.hide();hud.hide();overlay.show()
	panel_title("制作与资源署名","南楼求生 · 本地可玩原型")
	var text:=RichTextLabel.new();text.bbcode_enabled=true;text.custom_minimum_size=Vector2(1150,500);content.add_child(text)
	text.text="[font_size=25]丧尸模型、贴图与源动画[/font_size]\nZombie — Pixelhouse\n来源：[url=https://opengameart.org/content/zombie]OpenGameArt / Zombie[/url]\n作者网站：[url=http://www.pixelhouse.com.ar]Pixelhouse[/url]\n许可：[url=https://creativecommons.org/licenses/by/3.0/]Creative Commons Attribution 3.0[/url]\n本项目进行了单位、朝向、材质和动作适配，增加外观变体及受击动画。\n\n[font_size=25]第一人称手部[/font_size]\nGodot XR Tools — DigitalN8m4r3 / Miodrag Sejic\nCC0 1.0。原模型、手套贴图与骨骼手势；本项目调整握持、袖口连接和材质。\n\n[font_size=25]环境与运行基础[/font_size]\nambientCG：Plaster001 / Terrazzo003，CC0。\nColormatic Studios：第一人称控制参考，MIT。\nGodot Engine：MIT。\n\n场景扩展、玩法、检索界面、武器动作与合成音效在项目内制作。\n完整记录位于 game/licenses/资源来源.md。"
	text.meta_clicked.connect(func(url: Variant): OS.shell_open(str(url)))
	button(content,"返回主菜单",func(): action.emit("menu",null))
func toast(text: String, duration: float = 4.0) -> void:
	toast_label.text = text
	toast_time = duration
	toast_label.show()
func hit(killed: bool = false) -> void:
	hit_label.add_theme_color_override("font_color",AMBER if killed else INK)
	hit_time = .22 if killed else .12
	hit_label.show()
func damaged() -> void: damage_time = .8

func panel_title(text: String, subtitle: String) -> void:
	clear(content)
	var row := HBoxContainer.new();content.add_child(row)
	heading(row,text,33).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(row,"返回现场",func(): action.emit("resume",null),170).visible = view=="inventory"
	label(content,subtitle,16,MUTED)

func show_inventory(state: SurvivalState, base: bool = false) -> void:
	search_panel.hide()
	current_state = state
	view = "base" if base else "inventory"
	menu.hide(); hud.hide(); overlay.show()
	panel_title("安全屋 · 携行整备" if base else "随身物资 / 人物",state.result_text if base else "现场进行中")
	var row := HBoxContainer.new();row.add_theme_constant_override("separation",23);content.add_child(row)
	var left := VBoxContainer.new();left.custom_minimum_size.x=485;row.add_child(left)
	var filter_row := HBoxContainer.new();filter_row.add_theme_constant_override("separation",7);left.add_child(filter_row)
	for category in ["全部","可食用","武器","穿戴"]:
		var b := button(filter_row,category,func(): filter=category; refresh_inventory(),110)
		if filter==category: b.modulate=AMBER
	panel_capacity = label(left,"",16,AMBER)
	var scroll := ScrollContainer.new();scroll.custom_minimum_size=Vector2(485,426);left.add_child(scroll)
	list_box=VBoxContainer.new();list_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list_box.add_theme_constant_override("separation",7);scroll.add_child(list_box)
	details = label(left,"物品详情",16,MUTED)
	details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.custom_minimum_size=Vector2(480,90)
	equipment_box=VBoxContainer.new();equipment_box.custom_minimum_size.x=325;equipment_box.add_theme_constant_override("separation",10);row.add_child(equipment_box)
	var stats_scroll:=ScrollContainer.new();stats_scroll.custom_minimum_size=Vector2(365,580);stats_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;row.add_child(stats_scroll)
	stats_box=VBoxContainer.new();stats_box.custom_minimum_size.x=345;stats_box.add_theme_constant_override("separation",10);stats_scroll.add_child(stats_box)
	refresh_inventory()
	var foot := HBoxContainer.new();foot.add_theme_constant_override("separation",12);content.add_child(foot)
	if base:
		button(foot,"出发 · 搜寻物资",func(): action.emit("depart",null),260)
		button(foot,"武器升级",func(): action.emit("workshop",null),180)
		button(foot,"重置属性点",func(): action.emit("respec",null),180)
		button(foot,"返回主菜单",func(): action.emit("menu",null),180)

func refresh_inventory() -> void:
	if view not in ["inventory","base"] or not is_instance_valid(list_box): return
	var state := current_state
	clear(list_box);clear(equipment_box);clear(stats_box)
	panel_capacity.text="背包 %d / %d 格    ·    饮水 %d / 2" % [state.inventory.size(),state.capacity(),state.count_item("water",view=="base")]
	if state.inventory.is_empty(): label(list_box,"背包空着。为找到的物资留些位置。",16,MUTED)
	for item in state.inventory: item_row(item,false)
	if view=="base":
		label(list_box,"仓库  /  已带回 %d 件" % state.stash.size(),19,AMBER)
		if state.stash.is_empty(): label(list_box,"外出带回的物资会存放在这里。",16,MUTED)
		for item in state.stash: item_row(item,true)
	heading(equipment_box,"当前装备",25)
	for slot in Items.SLOTS:
		var equipped: Dictionary = state.equipment[slot]
		label(equipment_box,Items.SLOTS[slot],14,MUTED)
		var b := button(equipment_box,Items.caption(equipped) if not equipped.is_empty() else "未装备",func(): action.emit("unequip",slot),315)
		b.disabled=equipped.is_empty() or slot=="primary"
	button(equipment_box,"交换主备武器",func(): action.emit("swap",null)).disabled=state.equipment.secondary.is_empty()
	heading(stats_box,"人物机能",25)
	label(stats_box,"LV %d  ·  %s  ·  待分配 %d 点" % [state.level,"满级" if state.level==5 else "%d / %d 经验" % [state.xp,state.xp_needed()],state.points],17,AMBER)
	for key in Items.ATTRIBUTES:
		var r:=HBoxContainer.new();stats_box.add_child(r)
		label(r,"%s    %d" % [Items.ATTRIBUTES[key],state.attributes[key]],20).custom_minimum_size.x=245
		button(r,"＋",func(): action.emit("attribute",key),60).disabled=state.points<=0 or state.attributes[key]>=5
	label(stats_box,"力量：近战伤害 +6% / 点\n体质：最大生命 +10 / 点\n耐力：体力 +10、恢复 +3% / 点\n敏捷：移速 +2%、换武器 +5% / 点",15,MUTED)
	panel_status=label(stats_box,"",17,INK)
	panel_status.add_theme_constant_override("line_spacing",2)
	label(stats_box,"防护 %.0f%% · 移速 +%.0f%%\n近战伤害 +%.0f%%" % [state.armor()*100,(state.speed_multiplier()-1)*100,(state.damage_multiplier()-1)*100],17,GREEN)

func item_row(item: Dictionary, bank: bool) -> void:
	var data: Dictionary = Items.definition(item.id)
	if filter != "全部" and data.category != filter: return
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",6);list_box.add_child(row)
	var name_button:=button(row,Items.caption(item),func(): details.text=describe_item(item),203)
	name_button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	name_button.mouse_entered.connect(func(): details.text=describe_item(item))
	if bank:
		button(row,"取出",func(): action.emit("withdraw",item.uid),78)
	else:
		var verb: String = "食用" if data.category=="可食用" else ("装备" if data.has("slot") else ("装填" if data.get("ammunition",false) else "投掷"))
		button(row,verb,func(): action.emit("use",item.uid),70)
		if data.get("slot","")=="primary": button(row,"备用",func(): action.emit("secondary",item.uid),62)
		button(row,"存入" if view=="base" else "丢弃",func(): action.emit("deposit" if view=="base" else "drop",item.uid),66)
func describe_item(item: Dictionary) -> String:
	var data: Dictionary=Items.stats(item)
	var text: String="%s / %s\n%s" % [data.name,data.category,data.note]
	if data.get("ranged",false):
		text+="\n伤害 %.0f / 要害 ×%.1f   装填 %.2f 秒\n弹仓 %d / %d   背包备用 %d" % [data.damage,data.headshot,data.reload,int(item.get("loaded",0)),int(data.magazine),current_state.ammo_count(data.ammo)]
	elif data.get("ammunition",false): text+="\n剩余 %d 发" % int(item.get("quantity",data.quantity))
	elif data.has("damage"):
		var old: Dictionary=current_state.weapon()
		text+="\n轻击 %.0f（%+.0f）  重击 %.0f  距离 %.2fm" % [data.damage,float(data.damage)-float(old.damage),data.heavy,data.reach]
	elif item.id=="coat": text+="\n防护：%.0f%% → 18%%" % (current_state.armor()*100)
	elif item.id=="pack": text+="\n容量：%d → 8 格" % current_state.capacity()
	return text

func show_workshop(state: SurvivalState) -> void:
	current_state=state;view="workshop"
	search_panel.hide();menu.hide();hud.hide();overlay.show()
	panel_title("武器升级","本次试制升级免费 · 已拥有的扳手与球棍可在安全屋改装")
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(1210,560);content.add_child(scroll)
	var rows:=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rows.add_theme_constant_override("separation",20);scroll.add_child(rows)
	var count:=0
	for item in state.equipment.values()+state.inventory+state.stash:
		if item.get("id","") not in ["wrench","bat"]: continue
		count+=1
		var card:=PanelContainer.new();card.add_theme_stylebox_override("panel",style(Color("293933"),Color("53675b"),22));rows.add_child(card)
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",28);card.add_child(row)
		var info:=VBoxContainer.new();info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;info.add_theme_constant_override("separation",12);row.add_child(info)
		heading(info,Items.caption(item),28)
		label(info,"破势连击  /  斜击 → 上挑 → 下砸" if item.id=="wrench" else "破阵重击  /  击飞 → 撞倒后排 → 撞墙重创",20,AMBER)
		label(info,"连续点击左键衔接三段攻击；受击、换武器或暂停会结束连段。" if item.id=="wrench" else "按住左键蓄力，松开重击；轻击可横扫身前多个目标。",16,MUTED)
		var upgraded: bool=item.get("melee_upgrade",false)
		var b:=button(row,"已升级" if upgraded else "升级此武器",func(): action.emit("upgrade_melee",item.uid),180)
		b.disabled=upgraded
	if count==0: label(rows,"尚未拥有可升级武器。",20,MUTED)
	button(content,"返回安全屋",func(): action.emit("workshop_back",null),220)

func show_dead(state: SurvivalState) -> void:
	search_panel.hide()
	view="dead";menu.hide();hud.hide();overlay.show()
	panel_title("本次外出结束",state.result_text)
	heading(content,"成长还在。重新准备。",45)
	label(content,"等级 %d    已有属性点 %d\n回安全屋整理装备，再选择一条路线。" % [state.level,state.points],22,MUTED)
	button(content,"返回安全屋",func(): action.emit("recover",null))

func show_settings(values: Dictionary, origin: String) -> void:
	search_panel.hide()
	settings_origin=origin
	view="settings";menu.hide();hud.hide();overlay.show()
	panel_title("视角、打击反馈与操作","调整在当前现场立即生效。点击键位后按新键，Esc 取消。")
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",35);content.add_child(row)
	var left:=VBoxContainer.new();left.custom_minimum_size.x=500;left.add_theme_constant_override("separation",18);row.add_child(left)
	for data in [["视野范围","fov",60,95,1],["鼠标灵敏度","sensitivity",.025,.2,.005],["环境亮度","brightness",.8,1.6,.05],["主音量","volume",0,1,.05],["镜头打击回弹","shake",0,1,.05]]:
		var key: String=data[1]
		var r:=HBoxContainer.new();left.add_child(r)
		label(r,str(data[0]),17).custom_minimum_size.x=170
		var slider:=HSlider.new();slider.min_value=data[2];slider.max_value=data[3];slider.step=data[4];slider.value=float(values[key]);slider.custom_minimum_size=Vector2(230,32);r.add_child(slider)
		var number:=label(r,"%.2f" % float(values[key]),16,MUTED)
		slider.value_changed.connect(func(value: float): number.text="%.2f" % value;action.emit("setting",{ "key":key,"value":value }))
	for data in [["行走时轻微晃动","head_bob"],["少量血迹效果","blood"]]:
		var key: String=data[1]
		var check:=CheckButton.new();check.text=data[0];check.button_pressed=bool(values[key]);left.add_child(check)
		check.toggled.connect(func(value: bool): action.emit("setting",{"key":key,"value":value}))
	label(left,"Esc 始终用于暂停。Tab、鼠标左右键\n与数字 1 / 2 为固定操作。",17,MUTED)
	var right:=GridContainer.new();right.columns=2;right.add_theme_constant_override("v_separation",6);row.add_child(right)
	binding_buttons.clear()
	for data in [["前进","move_forward"],["后退","move_back"],["左移","move_left"],["右移","move_right"],["交互","interact"],["冲刺","sprint"],["蹲行","crouch"],["手电","flashlight"],["快速吃喝","quick_use"],["投瓶","throw"],["装填","reload"],["推开","shove"]]:
		var key: String=data[1]
		label(right,str(data[0]),16).custom_minimum_size.x=160
		var events:=InputMap.action_get_events(key)
		var b:=button(right,OS.get_keycode_string(events[0].physical_keycode),func(): pass,220)
		b.custom_minimum_size.y=35
		binding_buttons[key]=b
		b.pressed.connect(func(): binding_action=key;binding_button=b;b.text="按下新按键…")
	button(content,"返回",func(): action.emit("settings_back",settings_origin))

func _input(event: InputEvent) -> void:
	if binding_action.is_empty() or not event is InputEventKey or not event.pressed or event.echo: return
	get_viewport().set_input_as_handled()
	if event.keycode != KEY_ESCAPE:
		if event.keycode in [KEY_TAB,KEY_ENTER,KEY_1,KEY_2,KEY_F12]:
			binding_button.text="此键已保留";return
		for key in binding_buttons:
			if key==binding_action: continue
			if InputMap.action_get_events(key)[0].physical_keycode==event.physical_keycode:
				binding_button.text="按键已占用";return
		action.emit("binding",{"action":binding_action,"key":event.physical_keycode})
	binding_button.text=OS.get_keycode_string(InputMap.action_get_events(binding_action)[0].physical_keycode)
	binding_action=""

func update_hud(state: SurvivalState, room: String, outdoors: bool=false) -> void:
	hp_bar.max_value=state.maximum_hp();hp_bar.value=state.hp
	stamina_bar.max_value=state.maximum_stamina();stamina_bar.value=state.stamina
	hp_label.text="生命  %d / %d" % [ceili(state.hp),roundi(state.maximum_hp())]
	stamina_label.text="体力  %d / %d" % [ceili(state.stamina),roundi(state.maximum_stamina())]
	level_label.text="LV %d   %s" % [state.level,"+%d 点" % state.points if state.points>0 else ("已满级" if state.level==5 else "%d / %d" % [state.xp,state.xp_needed()])]
	xp_bar.max_value=state.xp_needed();xp_bar.value=state.xp if state.level<5 else state.xp_needed()
	location.text=("南街 / 地面  ·  " if outdoors else "南楼 / 03 层  ·  ")+room
	var weapon: Dictionary=state.weapon()
	weapon_label.visible=weapon.get("ranged",false)
	if weapon_label.visible:
		weapon_label.text="%s\n弹仓 %d / %d   ·   备用 %d" % [weapon.name,int(state.equipment.primary.get("loaded",0)),int(weapon.magazine),state.ammo_count(weapon.ammo)]
	objective.text="背包 %d / %d" % [state.inventory.size(),state.capacity()]
	var statuses:=state.statuses()
	status_label.text=statuses[0] if not statuses.is_empty() else "饱食 %d   水分 %d" % [roundi(state.nutrition),roundi(state.hydration)]
	if view in ["base","inventory"] and is_instance_valid(panel_status):
		panel_status.text="生命 %d / %d\n体力 %d / %d\n饱食 %d   水分 %d\n%s" % [ceili(state.hp),roundi(state.maximum_hp()),ceili(state.stamina),roundi(state.maximum_stamina()),roundi(state.nutrition),roundi(state.hydration),"\n".join(statuses)]
func _process(delta: float) -> void:
	toast_time=maxf(0,toast_time-delta)
	# Keep notifications outside the inventory heading and buttons.
	anchor(toast_label,Control.PRESET_CENTER_TOP,-600,600,6 if overlay.visible else 79,38 if overlay.visible else 134)
	toast_label.visible=toast_time>0
	toast_label.modulate.a=minf(1,toast_time)
	reticle.visible=view=="game" and not search_spinner.visible
	hit_time=maxf(0,hit_time-delta);hit_label.visible=hit_time>0
	damage_time=maxf(0,damage_time-delta)
	damage_layer.material.set_shader_parameter("amount",damage_time*.6)
