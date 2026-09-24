extends Node3D

const PLAYER_SCRIPT = preload("res://player.gd")

var player: CharacterBody3D
var camera: Camera3D
var spring_arm: SpringArm3D
var ui: CanvasLayer
var world_env: WorldEnvironment
var day_time := 0.0
var game_day := 1
var camera_pitch := -12.0
var built_purifier := false
var built_shelter := false
var mission_stage := 0
var world_objects: Array[Node3D] = []
var save_path := "user://afterwar_save.json"
var message_timer := 0.0
var interaction_target = null
var npc = null
var fire_light = null

func _ready():
    _configure_input()

    # Crear la interfaz primero para que el juego nunca quede
    # completamente vacío si falla una etapa posterior.
    _build_ui()
    _show_message("Iniciando AFTERWAR...", 10.0)

    _build_world()
    _spawn_player()
    _load_game()

    _show_message("AÑO 1 — Valle 17. Encontrá agua y construí un refugio.", 6.0)

func _process(delta):
    day_time += delta
    if day_time >= 180.0:
        day_time -= 180.0
        game_day += 1
        _show_message("Comienza el día %d." % game_day, 3.0)
        _save_game()
    _update_environment()
    _update_interaction()
    if message_timer > 0:
        message_timer -= delta
        if message_timer <= 0 and ui:
            ui.get_node("Root/Message").text = ""


func _configure_input():
    var actions := {
        "move_forward": KEY_W,
        "move_back": KEY_S,
        "move_left": KEY_A,
        "move_right": KEY_D,
        "interact": KEY_E,
        "use_food": KEY_F,
        "use_water": KEY_G,
        "toggle_build": KEY_B
    }
    for action in actions.keys():
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        for existing in InputMap.action_get_events(action):
            InputMap.action_erase_event(action, existing)
        var ev := InputEventKey.new()
        ev.physical_keycode = int(actions[action])
        InputMap.action_add_event(action, ev)

func _build_world():
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#6b756f")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#c8cfca")
    env.ambient_light_energy = 0.8
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world_env = WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)

    var sun := DirectionalLight3D.new()
    sun.name = "Sun"
    sun.rotation_degrees = Vector3(-48, -25, 0)
    sun.light_energy = 1.15
    sun.shadow_enabled = true
    add_child(sun)

    var ground := StaticBody3D.new()
    ground.name = "Valle17Ground"
    add_child(ground)
    var ground_shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(256, 1, 256)
    ground_shape.shape = box
    ground_shape.position.y = -0.5
    ground.add_child(ground_shape)
    var mesh := MeshInstance3D.new()
    var plane := BoxMesh.new()
    plane.size = Vector3(256, 1, 256)
    mesh.mesh = plane
    mesh.position.y = -0.5
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#4e5547")
    mat.roughness = 1.0
    mesh.material_override = mat
    ground.add_child(mesh)

    _create_ruins()
    _create_tree_cluster()
    _create_interactable("Barril de agua", Vector3(8,0,3), "water", Color("#5b6c75"))
    _create_interactable("Caja de raciones", Vector3(-5,0,5), "food", Color("#7c6956"))
    _create_interactable("Chatarra", Vector3(4,0,-8), "metal", Color("#777b76"))
    _create_interactable("Madera", Vector3(-7,0,-6), "wood", Color("#6b4e36"))
    _create_npc()
    _create_label_marker(Vector3(8,2.6,3), "AGUA")
    _create_label_marker(Vector3(-5,2.4,5), "COMIDA")

func _create_ruins():
    var structures := [
        {"p":Vector3(20,2,-4),"s":Vector3(9,4,7),"c":"#5e5f5a"},
        {"p":Vector3(18,1.5,11),"s":Vector3(6,3,8),"c":"#69655e"},
        {"p":Vector3(-18,1.2,-12),"s":Vector3(8,2.4,5),"c":"#666b67"},
        {"p":Vector3(-14,3,13),"s":Vector3(12,6,6),"c":"#585c59"}
    ]
    for item in structures:
        var body := StaticBody3D.new()
        body.position = item.p
        add_child(body)
        var shape_node := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = item.s
        shape_node.shape = shape
        body.add_child(shape_node)
        var mesh := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = item.s
        mesh.mesh = box
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(item.c)
        mat.roughness = 0.98
        mesh.material_override = mat
        body.add_child(mesh)

func _create_tree_cluster():
    var positions := [Vector3(13,0,-18),Vector3(9,0,-20),Vector3(17,0,-23),Vector3(-22,0,18),Vector3(-26,0,13),Vector3(-20,0,23)]
    for p in positions:
        var trunk := MeshInstance3D.new()
        var cyl := CylinderMesh.new()
        cyl.top_radius = 0.2
        cyl.bottom_radius = 0.28
        cyl.height = 2.7
        trunk.mesh = cyl
        trunk.position = p + Vector3(0,1.35,0)
        var tmat := StandardMaterial3D.new()
        tmat.albedo_color = Color("#574a3c")
        trunk.material_override = tmat
        add_child(trunk)
        var crown := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 1.15
        sphere.height = 2.3
        crown.mesh = sphere
        crown.position = p + Vector3(0,3.0,0)
        var cmat := StandardMaterial3D.new()
        cmat.albedo_color = Color("#435744")
        cmat.roughness = 1.0
        crown.material_override = cmat
        add_child(crown)

func _create_interactable(label: String, pos: Vector3, kind: String, color: Color):
    var body := Area3D.new()
    body.name = label.replace(" ", "_")
    body.position = pos
    body.set_meta("kind", kind)
    body.set_meta("label", label)
    body.set_meta("used", false)
    var shape_node := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 1.4
    shape_node.shape = sphere
    body.add_child(shape_node)
    var mesh := MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size = Vector3(1.6,1.1,1.2)
    mesh.mesh = cube
    mesh.position.y = 0.55
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.85
    mesh.material_override = mat
    body.add_child(mesh)
    add_child(body)
    world_objects.append(body)

func _create_npc():
    npc = CharacterBody3D.new()
    npc.name = "Elena"
    npc.position = Vector3(-1,0,10)
    add_child(npc)
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.33
    capsule.height = 1.55
    shape.shape = capsule
    shape.position.y = 0.85
    npc.add_child(shape)
    var mesh := MeshInstance3D.new()
    var cap := CapsuleMesh.new()
    cap.radius = 0.33
    cap.height = 1.55
    mesh.mesh = cap
    mesh.position.y = 0.85
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#a07d58")
    mesh.material_override = mat
    npc.add_child(mesh)
    var label := Label3D.new()
    label.text = "Elena\nIngeniera hidráulica"
    label.position.y = 2.2
    label.modulate = Color("#ecf0ea")
    label.outline_size = 8
    npc.add_child(label)

func _create_label_marker(pos: Vector3, text: String):
    var label := Label3D.new()
    label.text = text
    label.position = pos
    label.modulate = Color("#e6eadf")
    label.outline_size = 8
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(label)

func _spawn_player():
    player = PLAYER_SCRIPT.new()
    player.name = "Survivor"
    player.position = Vector3(0, 0, 0)
    add_child(player)

    player.stats_changed.connect(_on_stats_changed)

    spring_arm = SpringArm3D.new()
    spring_arm.name = "CameraSpringArm"
    spring_arm.spring_length = 7.0
    spring_arm.position = Vector3(0, 2.2, 0)
    spring_arm.rotation_degrees = Vector3(-10.0, 0, 0)

    player.add_child(spring_arm)

    spring_arm.add_excluded_object(player.get_rid())

    camera = Camera3D.new()
    camera.name = "Camera3D"
    camera.fov = 68.0

    spring_arm.add_child(camera)
    camera.make_current()

func _build_ui():
    ui = CanvasLayer.new()
    ui.name = "UI"
    add_child(ui)
    var root := Control.new()
    root.name = "Root"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.add_child(root)

    var top := ColorRect.new()
    top.position = Vector2(18,18)
    top.size = Vector2(360,132)
    top.color = Color(0.06,0.07,0.07,0.82)
    root.add_child(top)
    var title := Label.new()
    title.position = Vector2(18,10)
    title.text = "AFTERWAR  •  VALLE 17"
    title.add_theme_font_size_override("font_size", 21)
    top.add_child(title)
    for spec in [["Hambre","Hunger",45], ["Sed","Thirst",78], ["Salud","Health",110]]:
        var l := Label.new()
        l.position = Vector2(18,spec[2])
        l.text = spec[0]
        top.add_child(l)
        var bar := ProgressBar.new()
        bar.name = spec[1]
        bar.position = Vector2(92,spec[2]+1)
        bar.size = Vector2(230,18)
        bar.max_value = 100
        bar.value = 100
        bar.show_percentage = false
        top.add_child(bar)

    var mission := Label.new()
    mission.name = "Mission"
    mission.position = Vector2(18,162)
    mission.add_theme_font_size_override("font_size", 20)
    mission.text = "MISIÓN\n⟶ Encontrá agua y construí un refugio."
    mission.add_theme_color_override("font_color", Color("#eff1e8"))
    root.add_child(mission)

    var inv := Label.new()
    inv.name = "Inventory"
    inv.position = Vector2(18,250)
    inv.add_theme_font_size_override("font_size", 17)
    inv.text = "Inventario"
    root.add_child(inv)

    var message := Label.new()
    message.name = "Message"
    message.position = Vector2(330,30)
    message.size = Vector2(620,80)
    message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message.add_theme_font_size_override("font_size", 20)
    root.add_child(message)

    var day_label := Label.new()
    day_label.name = "Day"
    day_label.position = Vector2(1040,24)
    day_label.size = Vector2(200,40)
    day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    day_label.add_theme_font_size_override("font_size", 20)
    root.add_child(day_label)

    _add_touch_button(root, "AGUA", Vector2(1030,500), Vector2(105,60), "use_water")
    _add_touch_button(root, "COMIDA", Vector2(1145,500), Vector2(105,60), "use_food")
    _add_touch_button(root, "INTERACTUAR", Vector2(1030,568), Vector2(220,60), "interact")
    _add_touch_button(root, "CONSTRUIR", Vector2(1030,636), Vector2(220,60), "build")

    var help := Label.new()
    help.position = Vector2(18,650)
    help.text = "PC: WASD • E interactuar • F comida • G agua • B construir"
    help.add_theme_font_size_override("font_size", 14)
    root.add_child(help)

    var joystick_base := ColorRect.new()
    joystick_base.name = "JoystickBase"
    joystick_base.position = Vector2(26,465)
    joystick_base.size = Vector2(150,150)
    joystick_base.color = Color(0.1,0.12,0.12,0.55)
    root.add_child(joystick_base)
    var joystick := Control.new()
    joystick.name = "Joystick"
    joystick.position = Vector2(46,485)
    joystick.size = Vector2(110,110)
    root.add_child(joystick)
    joystick.gui_input.connect(_on_joystick_input)

func _add_touch_button(root: Control, text_value: String, pos: Vector2, size: Vector2, action: String):
    var b := Button.new()
    b.text = text_value
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size", 16)
    b.pressed.connect(func(): _handle_action(action))
    root.add_child(b)

func _on_joystick_input(event):
    var joystick := ui.get_node("Root/Joystick")
    if event is InputEventScreenTouch or event is InputEventMouseButton:
        if event.pressed:
            player.touch_move = Vector2.ZERO
        else:
            player.touch_move = Vector2.ZERO
    elif event is InputEventScreenDrag or event is InputEventMouseMotion:
        var local := event.position - joystick.size * 0.5
        player.touch_move = Vector2(local.x, -local.y) / (joystick.size.x * 0.5)
        player.touch_move = player.touch_move.limit_length(1.0)

func _handle_action(action: String):
    match action:
        "use_water":
            if player.use_water():
                _show_message("Bebiste agua limpia.")
            else:
                _show_message("No tenés agua limpia. Purificala primero.")
        "use_food":
            if player.use_food():
                _show_message("Comiste una ración.")
            else:
                _show_message("No quedan raciones.")
        "interact": _interact()
        "build": _build_mode()

func _input(event):
    if event.is_action_pressed("use_water"):
        _handle_action("use_water")
    elif event.is_action_pressed("use_food"):
        _handle_action("use_food")
    elif event.is_action_pressed("interact"):
        _handle_action("interact")
    elif event.is_action_pressed("toggle_build"):
        _handle_action("build")

func _update_interaction():
    interaction_target = null
    var best_dist := 3.0
    for obj in world_objects:
        if is_instance_valid(obj):
            var dist := player.global_position.distance_to(obj.global_position)
            if dist < best_dist:
                best_dist = dist
                interaction_target = obj
    if is_instance_valid(npc):
        var npc_dist := player.global_position.distance_to(npc.global_position)
        if npc_dist < best_dist:
            best_dist = npc_dist
            interaction_target = npc
    if ui:
        var msg := ""
        if interaction_target:
            if interaction_target == npc:
                msg = "E / INTERACTUAR: hablar con Elena"
            else:
                msg = "E / INTERACTUAR: " + str(interaction_target.get_meta("label"))
        ui.get_node("Root/Message").text = msg if message_timer <= 0 else ui.get_node("Root/Message").text

func _interact():
    if not interaction_target:
        _show_message("No hay nada cercano con lo que interactuar.")
        return
    if interaction_target == npc:
        _show_message("Elena: “La bomba todavía podría funcionar. Necesitamos agua limpia.”", 5.0)
        if mission_stage == 0:
            mission_stage = 1
        return
    var kind := str(interaction_target.get_meta("kind"))
    if kind == "water":
        player.give_item("dirty_water", 2)
        _show_message("Recolectaste 2 unidades de agua contaminada. Purificalas.")
    elif kind == "purifier":
        if player.inventory.get("dirty_water", 0) >= 1:
            player.inventory["dirty_water"] -= 1
            player.give_item("clean_water", 1)
            _show_message("Purificaste 1 unidad de agua. Ahora podés beberla.")
        else:
            _show_message("El purificador necesita agua contaminada.")
    elif kind == "food":
        player.give_item("ration", 2)
        _show_message("Encontraste 2 raciones.")
    elif kind == "wood":
        player.give_item("wood", 4)
        _show_message("Recogiste madera.")
    elif kind == "metal":
        player.give_item("metal", 3)
        _show_message("Recuperaste metal de la chatarra.")
    interaction_target.set_meta("used", true)
    _save_game()

func _build_mode():
    if not built_purifier:
        var cost := {"wood":4,"metal":2}
        if player.has_items(cost):
            player.consume_items(cost)
            built_purifier = true
            mission_stage = max(mission_stage, 2)
            _create_structure(Vector3(3,0,-2), "Purificador", Vector3(2.2,1.3,1.8), Color("#6b7470"), "purifier")
            _show_message("Purificador improvisado construido. Ahora tenés que construir el refugio.", 5.0)
        else:
            _show_message("Purificador: requiere 4 madera + 2 metal.")
    elif not built_shelter:
        var cost2 := {"wood":8,"metal":3}
        if player.has_items(cost2):
            player.consume_items(cost2)
            built_shelter = true
            mission_stage = 3
            _create_structure(Vector3(-3,0,-1), "Refugio permanente", Vector3(5,2.4,4), Color("#665f52"))
            _show_message("Refugio construido. Objetivo del vertical slice alcanzado.", 8.0)
            _save_game()
        else:
            _show_message("Refugio: requiere 8 madera + 3 metal.")
    else:
        _show_message("El refugio ya está construido. El siguiente paso será mantener a la comunidad.")

func _create_structure(pos: Vector3, label_text: String, size: Vector3, color: Color, kind: String = "structure"):
    var body := StaticBody3D.new()
    body.position = pos
    body.set_meta("kind", kind)
    body.set_meta("label", label_text)
    add_child(body)
    if kind == "purifier":
        world_objects.append(body)
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    shape_node.shape = shape
    shape_node.position.y = size.y * 0.5
    body.add_child(shape_node)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.position.y = size.y * 0.5
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.98
    mesh.material_override = mat
    body.add_child(mesh)
    var label := Label3D.new()
    label.text = label_text
    label.position.y = size.y + 0.6
    label.modulate = Color("#e6eadf")
    label.outline_size = 7
    body.add_child(label)

func _update_environment():
    if not world_env:
        return
    var phase := day_time / 180.0
    var sun := get_node_or_null("Sun") as DirectionalLight3D
    if sun:
        var angle := lerp(-20.0, 250.0, phase)
        sun.rotation_degrees = Vector3(angle, -25, 0)
        sun.light_energy = lerp(0.25, 1.2, clamp(sin(phase * TAU) * 0.5 + 0.5, 0.15, 1.0))

    var h := game_day
    if ui:
        ui.get_node("Root/Day").text = "DÍA %d" % h
        var inv := player.inventory
        ui.get_node("Root/Inventory").text = "Inventario\nAgua sucia: %d  |  Agua limpia: %d\nRaciones: %d  |  Madera: %d  |  Metal: %d" % [inv.get("dirty_water",0), inv.get("clean_water",0), inv.get("ration",0), inv.get("wood",0), inv.get("metal",0)]
        var mission_text := ""
        if not built_purifier:
            mission_text = "⟶ Recolectá materiales y construí un purificador."
        elif not built_shelter:
            mission_text = "⟶ Construí el refugio permanente."
        else:
            mission_text = "✓ Refugio construido.\n⟶ Próxima fase: comunidad y supervivientes."
        ui.get_node("Root/Mission").text = "MISIÓN\n" + mission_text

func _on_stats_changed(hunger, thirst, health):
    if not ui:
        return
    var top := ui.get_node("Root/ColorRect")
    top.get_node("Hunger").value = hunger
    top.get_node("Thirst").value = thirst
    top.get_node("Health").value = health

func _show_message(text: String, duration := 3.0):
    if not ui:
        return
    ui.get_node("Root/Message").text = text
    message_timer = duration

func _save_game():
    var data := {
        "player":{"position":[player.position.x,player.position.y,player.position.z],"hunger":player.hunger,"thirst":player.thirst,"health":player.health,"inventory":player.inventory},
        "world":{"day":game_day,"day_time":day_time,"built_purifier":built_purifier,"built_shelter":built_shelter,"mission_stage":mission_stage}
    }
    var file := FileAccess.open(save_path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))

func _load_game():
    if not FileAccess.file_exists(save_path):
        return
    var file := FileAccess.open(save_path, FileAccess.READ)
    if not file:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var pdata = parsed.get("player", {})
    if pdata.has("position"):
        var pos = pdata["position"]
        if pos is Array and pos.size() >= 3:
            player.position = Vector3(float(pos[0]),float(pos[1]),float(pos[2]))
    player.hunger = clamp(float(pdata.get("hunger", player.hunger)),0.0,100.0)
    player.thirst = clamp(float(pdata.get("thirst", player.thirst)),0.0,100.0)
    player.health = clamp(float(pdata.get("health", player.health)),0.0,100.0)
    var inv = pdata.get("inventory", {})
    if inv is Dictionary:
        for k in inv.keys():
            player.inventory[str(k)] = int(inv[k])
    var wdata = parsed.get("world", {})
    game_day = max(1,int(wdata.get("day",1)))
    day_time = max(0.0,float(wdata.get("day_time",0.0)))
    built_purifier = bool(wdata.get("built_purifier",false))
    built_shelter = bool(wdata.get("built_shelter",false))
    mission_stage = int(wdata.get("mission_stage",0))
    if built_purifier:
        _create_structure(Vector3(3,0,-2), "Purificador", Vector3(2.2,1.3,1.8), Color("#6b7470"), "purifier")
    if built_shelter:
        _create_structure(Vector3(-3,0,-1), "Refugio permanente", Vector3(5,2.4,4), Color("#665f52"))

func _notification(what):
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save_game()
