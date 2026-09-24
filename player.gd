extends CharacterBody3D

signal stats_changed(hunger: float, thirst: float, health: float)
signal player_interacted(target)

@export var walk_speed := 4.3
@export var acceleration := 12.0
@export var gravity := 18.0

var hunger := 82.0
var thirst := 76.0
var health := 100.0
var inventory := {"dirty_water": 2, "clean_water": 0, "ration": 3, "wood": 3, "metal": 1, "medicine": 0}
var touch_move := Vector2.ZERO
var camera_yaw := 0.0
var camera_pitch := -12.0

func _ready():
    _build_visuals()
    stats_changed.emit(hunger, thirst, health)

func _build_visuals():
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.65
    shape.shape = capsule
    shape.position.y = 0.9
    add_child(shape)

    var mesh := MeshInstance3D.new()
    var capsule_mesh := CapsuleMesh.new()
    capsule_mesh.radius = 0.38
    capsule_mesh.height = 1.65
    mesh.mesh = capsule_mesh
    mesh.position.y = 0.9
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#87908c")
    mat.roughness = 0.92
    mesh.material_override = mat
    add_child(mesh)

    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.24
    sphere.height = 0.48
    head.mesh = sphere
    head.position.y = 1.95
    var head_mat := StandardMaterial3D.new()
    head_mat.albedo_color = Color("#b79a83")
    head.material_override = head_mat
    add_child(head)

func _physics_process(delta):
    _update_survival(delta)
    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = -0.5

    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if touch_move.length() > 0.1:
        input_vec = touch_move
    input_vec = input_vec.limit_length(1.0)

    var cam_basis := global_transform.basis
    var forward := -cam_basis.z
    forward.y = 0
    forward = forward.normalized()
    var right := cam_basis.x
    right.y = 0
    right = right.normalized()
    var direction := (right * input_vec.x + forward * input_vec.y).normalized()

    var target_vel := direction * walk_speed
    velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
    velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)
    move_and_slide()

    if direction.length() > 0.2:
        var target_angle := atan2(direction.x, direction.z)
        rotation.y = lerp_angle(rotation.y, target_angle, min(1.0, delta * 8.0))

func _update_survival(delta):
    hunger = max(0.0, hunger - (2.0 / 60.0) * delta)
    thirst = max(0.0, thirst - (3.5 / 60.0) * delta)
    if thirst <= 0.0:
        health = max(0.0, health - (7.0 / 60.0) * delta)
    elif hunger <= 0.0:
        health = max(0.0, health - (3.0 / 60.0) * delta)
    stats_changed.emit(hunger, thirst, health)

func use_food() -> bool:
    if inventory.get("ration", 0) <= 0:
        return false
    inventory["ration"] -= 1
    hunger = min(100.0, hunger + 30.0)
    stats_changed.emit(hunger, thirst, health)
    return true

func use_water() -> bool:
    if inventory.get("clean_water", 0) <= 0:
        return false
    inventory["clean_water"] -= 1
    thirst = min(100.0, thirst + 38.0)
    stats_changed.emit(hunger, thirst, health)
    return true

func give_item(item_id: String, amount: int = 1):
    inventory[item_id] = inventory.get(item_id, 0) + amount

func has_items(cost: Dictionary) -> bool:
    for key in cost.keys():
        if inventory.get(key, 0) < int(cost[key]):
            return false
    return true

func consume_items(cost: Dictionary):
    for key in cost.keys():
        inventory[key] = inventory.get(key, 0) - int(cost[key])
