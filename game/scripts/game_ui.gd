class_name RepairUI
extends CanvasLayer

signal start_requested(continue_save: bool)
signal resume_requested
signal submit_requested
signal reset_requested
signal quit_requested
signal setting_changed(key: String, value: Variant)
var root: Control
var menu: Control
var hud: Control
var ticket: Control
var settings_panel: Control
var headline: Label
var subtitle: Label
var checks_label: Label
var submit_button: Button
var interaction: Label
var interaction_detail: Label
var notification: Label
var diagnostic: Label
var location_label: Label
var reticle: Label
var progress: ProgressBar
var first_button: Button
var continue_button: Button
var pause_button: Button
var body_font: SystemFont
var title_font: SystemFont
var mono_font: SystemFont
var toast_timer := 0.0
var binding_action := ""
var binding_button: Button
var is_pause := false
var menu_body: VBoxContainer
var setting_sliders: Dictionary = {}
var setting_values: Dictionary = {}
var binding_buttons: Dictionary = {}
var bob_switch: CheckButton
const INK := Color("d4d8d0")
const MUTED := Color("94a29f")
const AMBER := Color("c99a53")

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	body_font = SystemFont.new()
	body_font.font_names = PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "Microsoft YaHei", "sans-serif"])
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["Songti SC", "Noto Serif CJK SC", "serif"])
	mono_font = SystemFont.new()
	mono_font.font_names = PackedStringArray(["Menlo", "Consolas", "monospace"])
	var theme := Theme.new()
	theme.default_font = body_font
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", INK)
	root.theme = theme
	build_menu()
	build_hud()
	build_ticket()
	build_settings()

func panel_style(color: Color, border: Color = Color.TRANSPARENT, margin: float = 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	return s

func full(parent: Control) -> Control:
	var c := Control.new()
	parent.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

func label(parent: Node, text: String, size: int = 18, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 48
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_disabled_color", Color("718078"))
	b.add_theme_stylebox_override("normal", panel_style(Color(0.10,0.14,0.15,0.78), Color(0.55,0.64,0.61,0.22), 13))
	b.add_theme_stylebox_override("hover", panel_style(Color(0.24,0.27,0.25,0.95), AMBER, 13))
	b.add_theme_stylebox_override("focus", panel_style(Color.TRANSPARENT, AMBER, 13))
	b.add_theme_stylebox_override("pressed", panel_style(Color("41433a"), AMBER, 13))
	parent.add_child(b)
	b.pressed.connect(callback)
	return b

func build_menu() -> void:
	menu = full(root)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){float a=mix(0.93,0.0,smoothstep(0.1,0.76,UV.x));COLOR=vec4(0.033,0.047,0.050,a);}"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	veil.material = mat
	menu.add_child(veil)
	menu_body = VBoxContainer.new()
	menu_body.position = Vector2(82,95)
	menu_body.size = Vector2(440,680)
	menu_body.add_theme_constant_override("separation", 17)
	menu.add_child(menu_body)
	label(menu_body,"南楼  /  住宅维护记录",16,AMBER)
	headline = label(menu_body,"异常房屋\n维修员",62)
	headline.add_theme_font_override("font", title_font)
	headline.add_theme_constant_override("line_spacing",8)
	subtitle = label(menu_body,"住户已经搬走。\n报修单仍在打印。",20,MUTED)
	subtitle.add_theme_constant_override("line_spacing",8)
	var gap := Control.new()
	gap.custom_minimum_size.y = 22
	menu_body.add_child(gap)
	first_button = button(menu_body,"领取工单     →     302",func(): start_requested.emit(false))
	continue_button = button(menu_body,"继续上次检修",func(): start_requested.emit(true))
	pause_button = button(menu_body,"返回现场",func(): resume_requested.emit())
	pause_button.hide()
	button(menu_body,"视角、声音与操作",func(): settings_panel.show(); menu.hide())
	button(menu_body,"结束值班",func(): quit_requested.emit())
	var foot := label(menu,"302  ·  水不往下流\n可玩原型  /  第一章",15,MUTED)
	foot.position = Vector2(84,800)
	first_button.grab_focus()

func build_hud() -> void:
	hud = full(root)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.hide()
	location_label = label(hud,"南楼  /  03 层\n302 · 检修中",17,MUTED)
	location_label.position = Vector2(40,30)
	var keys := label(hud,"Tab  工单     H  提示     Esc  暂停",15,MUTED)
	keys.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	keys.offset_left = -350
	keys.offset_top = 36
	keys.offset_right = -20
	keys.offset_bottom = 68
	reticle = label(hud,"·",30,INK)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.offset_left = -6
	reticle.offset_top = -20
	reticle.offset_right = 12
	reticle.offset_bottom = 22
	interaction = label(hud,"",25)
	interaction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	interaction.offset_left = -520
	interaction.offset_right = 520
	interaction.offset_top = -144
	interaction.offset_bottom = -102
	interaction.add_theme_color_override("font_shadow_color",Color.BLACK)
	interaction.add_theme_constant_override("shadow_offset_y",2)
	interaction_detail = label(hud,"",16,MUTED)
	interaction_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_detail.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_detail.offset_left = -520
	interaction_detail.offset_right = 520
	interaction_detail.offset_top = -100
	interaction_detail.offset_bottom = -66
	notification = label(hud,"",19)
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notification.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notification.offset_left = -490
	notification.offset_right = 490
	notification.offset_top = 92
	notification.offset_bottom = 178
	notification.add_theme_color_override("font_shadow_color",Color.BLACK)
	notification.add_theme_constant_override("shadow_offset_y",2)
	diagnostic = label(hud,"",21,AMBER)
	diagnostic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diagnostic.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	diagnostic.offset_left = -450
	diagnostic.offset_right = 450
	diagnostic.offset_top = 118
	diagnostic.offset_bottom = 172
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.max_value = 1
	progress.add_theme_stylebox_override("background",panel_style(Color(0.05,0.08,0.09,.8),Color.TRANSPARENT,0))
	progress.add_theme_stylebox_override("fill",panel_style(AMBER,Color.TRANSPARENT,0))
	hud.add_child(progress)
	progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	progress.offset_left = -68
	progress.offset_right = 68
	progress.offset_top = 46
	progress.offset_bottom = 50
	progress.hide()

func centered_panel(parent: Control, size: Vector2, color: Color) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel",panel_style(color,Color("65716b"),32))
	parent.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -size.x/2
	p.offset_top = -size.y/2
	p.offset_right = size.x/2
	p.offset_bottom = size.y/2
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",16)
	p.add_child(v)
	return v

func darken(parent: Control) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.035,0.04,0.73)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shade)

func build_ticket() -> void:
	ticket = full(root)
	darken(ticket)
	var v := centered_panel(ticket,Vector2(720,700),Color("c7c9bd"))
	var dark := Color("26312e")
	label(v,"南楼物业  /  夜间维修站",17,Color("59645d"))
	label(v,"302 号检修工单",36,dark).add_theme_font_override("font",title_font)
	label(v,"水流反向，台面器物悬浮。\n住户登记：空置   /   作业范围：厨房、客厅",18,dark)
	label(v,"验收记录",21,dark)
	checks_label = label(v,"",20,dark)
	checks_label.add_theme_constant_override("line_spacing",17)
	label(v,"备注：带载调向将影响相邻支路。\n校准前请接入回收旁路。",17,Color("60695f"))
	submit_button = button(v,"签收工单",func(): submit_requested.emit())
	button(v,"返回现场    [Tab]",func(): resume_requested.emit())
	ticket.hide()

func build_settings() -> void:
	settings_panel = full(root)
	darken(settings_panel)
	var v := centered_panel(settings_panel,Vector2(710,790),Color("263432"))
	label(v,"视角、声音与操作",30)
	for data in [["鼠标灵敏度","sensitivity",0.025,0.20,0.085,0.005],["视野范围","fov",60,95,74,1],["环境亮度","brightness",0.8,1.6,1.05,0.05],["主音量","volume",0,1,0.65,0.05]]:
		var row := HBoxContainer.new()
		v.add_child(row)
		label(row,data[0],17).custom_minimum_size.x = 165
		var slider := HSlider.new()
		slider.min_value = data[2]
		slider.max_value = data[3]
		slider.step = data[5]
		slider.value = data[4]
		slider.custom_minimum_size = Vector2(330,28)
		row.add_child(slider)
		var value_label := label(row,"%.2f" % float(data[4]),16,MUTED)
		var key: String = data[1]
		setting_sliders[key] = slider
		setting_values[key] = value_label
		slider.value_changed.connect(func(value: float): value_label.text = "%.2f" % value; setting_changed.emit(key,value))
	var bob := CheckButton.new()
	bob_switch = bob
	bob.text = "轻微行走晃动（默认关闭）"
	v.add_child(bob)
	bob.toggled.connect(func(value: bool): setting_changed.emit("head_bob",value))
	label(v,"键位 · 点击后按下新按键；Esc 取消",16,MUTED)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",7)
	v.add_child(grid)
	for data in [["前进","move_forward"],["后退","move_back"],["左移","move_left"],["右移","move_right"],["交互 / 替代扳手操作","interact"],["慢行","walk_slow"]]:
		label(grid,data[0],16).custom_minimum_size.x = 300
		var action: String = data[1]
		var events := InputMap.action_get_events(action)
		var caption := OS.get_keycode_string(events[0].physical_keycode) if not events.is_empty() else "未设置"
		var b := button(grid,caption,func(): pass)
		binding_buttons[action] = b
		b.custom_minimum_size = Vector2(200,36)
		b.pressed.connect(func(): binding_action = action; binding_button = b; b.text = "请按键…")
	button(v,"返回",func(): settings_panel.hide(); menu.show(); (pause_button if is_pause else first_button).grab_focus())
	settings_panel.hide()

func sync_settings(values: Dictionary) -> void:
	for key in setting_sliders:
		setting_sliders[key].set_value_no_signal(values[key])
		setting_values[key].text = "%.2f" % float(values[key])
	bob_switch.set_pressed_no_signal(bool(values.head_bob))
	for action in binding_buttons:
		var events := InputMap.action_get_events(action)
		binding_buttons[action].text = OS.get_keycode_string(events[0].physical_keycode)

func _input(event: InputEvent) -> void:
	if binding_action.is_empty() and settings_panel.visible and event.is_action_pressed("pause_game"):
		settings_panel.hide()
		menu.show()
		(pause_button if is_pause else first_button).grab_focus()
		get_viewport().set_input_as_handled()
		return
	if binding_action.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.keycode != KEY_ESCAPE:
		var reserved := [KEY_TAB,KEY_H,KEY_ENTER,KEY_F12]
		if event.keycode in reserved:
			binding_button.text = "此键已保留，请换一个"
			return
		for a in ["move_forward","move_back","move_left","move_right","interact","walk_slow"]:
			if a != binding_action:
				for bound in InputMap.action_get_events(a):
					if bound is InputEventKey and bound.physical_keycode == event.physical_keycode:
						binding_button.text = "按键已占用"
						return
		InputMap.action_erase_events(binding_action)
		var key := InputEventKey.new()
		key.physical_keycode = event.physical_keycode
		InputMap.action_add_event(binding_action,key)
		setting_changed.emit("binding:" + binding_action,event.physical_keycode)
	var events := InputMap.action_get_events(binding_action)
	binding_button.text = OS.get_keycode_string(events[0].physical_keycode)
	binding_action = ""

func _process(delta: float) -> void:
	toast_timer = maxf(0,toast_timer-delta)
	notification.modulate.a = minf(1,toast_timer)

func toast(text: String, duration: float = 5.5) -> void:
	notification.text = text
	toast_timer = duration

func show_menu(paused: bool, has_save: bool) -> void:
	is_pause = paused
	menu.show()
	hud.hide()
	ticket.hide()
	settings_panel.hide()
	headline.text = "检修暂停" if paused else "异常房屋\n维修员"
	subtitle.text = "现场状态已保存。" if paused else "住户已经搬走。\n报修单仍在打印。"
	pause_button.visible = paused
	first_button.visible = not paused
	continue_button.visible = not paused and has_save
	if paused: pause_button.grab_focus()
	else: first_button.grab_focus()

func show_game() -> void:
	menu.hide()
	ticket.hide()
	settings_panel.hide()
	hud.show()

func show_ticket(state: RepairState) -> void:
	menu.hide()
	ticket.show()
	hud.hide()
	var lines := PackedStringArray()
	for check in state.checks():
		lines.append(("✓  " if check[1] else "□  ") + check[0])
	checks_label.text = "\n".join(lines)
	submit_button.disabled = not state.can_complete() or state.completed
	submit_button.text = "已签收 · 返回走廊查看打印机" if state.completed else ("签收工单" if state.can_complete() else "检查项尚未全部通过")

func show_ending() -> void:
	menu.show()
	hud.hide()
	ticket.hide()
	headline.text = "下一张工单\n401"
	subtitle.text = "卧室长度异常。\n\n可墙上的建筑图，只有三层。"
	first_button.show()
	first_button.text = "重新检修 302"
	continue_button.hide()
	pause_button.hide()
	first_button.grab_focus()
