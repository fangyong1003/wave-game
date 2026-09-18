extends SceneTree

const State = preload("res://scripts/repair_state.gd")
var failures := 0
var assertions := 0

func check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(description)

func drain(s: RepairState) -> void:
	s.act("hose")
	s.act("connect")
	if not s.bypass_open: s.act("bypass")
	for i in range(600): s.tick(1.0/60.0)

func repair(s: RepairState) -> void:
	if s.panel_closed: s.act("panel")
	drain(s)
	if not s.calibrated:
		if s.collar_locked: s.act("collar")
		s.act("calibrate")
	if not s.collar_locked: s.act("collar")
	if s.bypass_open: s.act("bypass")

func verify_all(s: RepairState) -> void:
	if not s.faucet_on: s.act("tap")
	s.act("tap")
	s.act("tap")
	s.measure("kitchen")
	s.measure("living")
	if not s.panel_closed: s.act("panel")

func _initialize() -> void:
	var s := State.new()
	check(s.kitchen_strength() == 1 and s.living_strength() == 0,"Initial fault must be local to kitchen")
	s.act("submit")
	check(not s.completed,"Cannot sign an unrepaired work order")
	s.act("bypass")
	check(not s.bypass_open,"Cannot open disconnected bypass")
	s.act("calibrate")
	check(not s.calibrated,"Locked collar prevents calibration")
	s.act("collar")
	s.act("calibrate")
	check(s.living_strength() > .9 and s.kitchen_strength() == 0,"Loaded calibration must transfer fault to lounge")
	repair(s)
	check(s.stable() and not s.transferred,"Wrong initial operation must remain recoverable")
	s.measure("kitchen")
	check(not s.kitchen_verified,"Measurement before faucet restart is not final verification")
	verify_all(s)
	check(s.can_complete(),"Repair and independent inspection must pass")
	s.act("submit")
	check(s.completed,"Completed job can be signed")
	var restored := State.new()
	check(restored.restore(s.serialize()) and restored.completed,"Completed save must round-trip")
	check(not restored.restore({"version":1,"pressure":"bad"}),"Corrupt pressure is rejected")

	s = State.new()
	drain(s)
	s.act("bypass")
	s.tick(2)
	check(s.pressure > .1,"Closing before calibration must bring fault back")
	repair(s)
	verify_all(s)
	s.act("panel")
	s.act("collar")
	check(not s.can_complete(),"Changing physical setup invalidates prior checks")
	repair(s)
	verify_all(s)
	check(s.can_complete(),"Reinspection after a change remains possible")

	s = State.new()
	s.act("hose");s.act("connect");s.act("bypass");s.tick(2)
	s.act("collar");s.act("calibrate");s.act("collar");s.act("bypass")
	s.tick(3)
	check(not s.stable(),"Early shutdown while residual pressure exists must fail inspection")
	var saved := State.new()
	check(saved.restore(s.serialize()),"Partial repair must save")
	repair(saved);verify_all(saved)
	check(saved.can_complete(),"Partial saved repair must be recoverable")

	# Repeated and out-of-order interactions must never strand the player.
	var rng := RandomNumberGenerator.new()
	rng.seed = 302
	var actions := ["hose","connect","bypass","collar","calibrate","panel","tap","submit"]
	for run in range(150):
		s = State.new()
		for i in range(70):
			s.act(actions[rng.randi_range(0,actions.size()-1)])
			s.tick(rng.randf_range(0,.6))
		check(s.pressure >= 0 and s.pressure <= 1,"Pressure stays bounded")
		if not s.completed:
			repair(s);verify_all(s)
			check(s.can_complete(),"Random interaction sequence %d remains recoverable" % run)
	print("REPAIR_STATE_TESTS: ",assertions," assertions, ",failures," failures")
	quit(1 if failures else 0)
