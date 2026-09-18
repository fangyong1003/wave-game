class_name SurvivalSearchSpinner
extends Control
## A rotating search indicator; the number reports real completion, not an indeterminate wait.
var value: float=0.0:
	set(next): value=clampf(next,0,1);queue_redraw()
var angle: float=-PI/2
var percent: Label
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	percent=Label.new();percent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	percent.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;percent.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	percent.add_theme_font_size_override("font_size",14);percent.add_theme_color_override("font_color",Color("d4d8d0"));percent.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(percent)
func begin() -> void:
	value=0;angle=-PI/2;show();queue_redraw()
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	angle=fposmod(angle+delta*TAU*1.2,TAU)
	percent.text="%d%%" % floori(value*100)
	queue_redraw()
func _draw() -> void:
	var center:=size*.5
	draw_circle(center,29,Color(.025,.045,.04,.82),true,-1,true)
	draw_arc(center,25,0,TAU,64,Color(.07,.11,.10,.9),5,true)
	draw_arc(center,25,0,TAU,64,Color(.60,.66,.64,.25),2,true)
	for i in range(24):
		var a:=angle-float(24-i)*TAU*.72/24
		draw_arc(center,25,a,a+TAU*.72/24,3,Color(.788,.604,.325,.16+.84*i/23.0),3,true)
	draw_circle(center+Vector2(cos(angle),sin(angle))*25,2.4,Color("d4d8d0"),true,-1,true)
