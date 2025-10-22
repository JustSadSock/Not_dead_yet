extends Node3D

class_name ApartmentCell

const Direction := {
        "NORTH": 0,
        "EAST": 1,
        "SOUTH": 2,
        "WEST": 3
}

@export var cell_size: float = 10.0
@export var wall_height: float = 3.0
@export var wall_thickness: float = 0.3
@export var door_width: float = 2.4
@export var door_height: float = 2.2
@export var floor_thickness: float = 0.2
@export var ceiling_thickness: float = 0.15
@export var trim_size: float = 0.1
@export var light_height: float = 2.7
@export var style_seed: int = 0 : set = set_style_seed, get = get_style_seed

var _connections: Array[bool] = [false, false, false, false]
var _initialized := false
var _style_seed: int = 0

var _visuals: Node3D
var _collider: StaticBody3D
var _wall_nodes: Array[Node3D] = []

var _wall_material: StandardMaterial3D
var _door_trim_material: StandardMaterial3D
var _floor_material: StandardMaterial3D
var _ceiling_material: StandardMaterial3D
var _lamp_material: StandardMaterial3D
var _light: OmniLight3D
var _lamp_instance: MeshInstance3D
var _props_container: Node3D

func _ready() -> void:
        _initialize_materials()
        _ensure_nodes()
        _apply_style()
        _rebuild()

func set_style_seed(value: int) -> void:
        _style_seed = value
        if _initialized:
                _apply_style()

func get_style_seed() -> int:
        return _style_seed

func set_connections(connections: Array[bool]) -> void:
        _connections = connections.duplicate()
        if _initialized:
                _rebuild()

func set_connection(direction: int, enabled: bool) -> void:
        if direction < 0 or direction >= _connections.size():
                return
        _connections[direction] = enabled
        if _initialized:
                _rebuild()

func _initialize_materials() -> void:
        if _wall_material == null:
                _wall_material = StandardMaterial3D.new()
                _wall_material.albedo_color = Color(0.85, 0.82, 0.76)
                _wall_material.roughness = 0.7
        if _door_trim_material == null:
                _door_trim_material = StandardMaterial3D.new()
                _door_trim_material.albedo_color = Color(0.63, 0.56, 0.5)
                _door_trim_material.roughness = 0.6
        if _floor_material == null:
                _floor_material = StandardMaterial3D.new()
                _floor_material.albedo_color = Color(0.36, 0.27, 0.19)
                _floor_material.roughness = 0.9
        if _ceiling_material == null:
                _ceiling_material = StandardMaterial3D.new()
                _ceiling_material.albedo_color = Color(0.92, 0.93, 0.94)
                _ceiling_material.roughness = 0.9

func _ensure_nodes() -> void:
        if _initialized:
                return
        _visuals = Node3D.new()
        _visuals.name = "Visuals"
        add_child(_visuals)

        _collider = StaticBody3D.new()
        _collider.name = "Collider"
        add_child(_collider)

        _create_floor()
        _create_ceiling()
        _create_light()
        _create_trim()

        _props_container = Node3D.new()
        _props_container.name = "Props"
        _visuals.add_child(_props_container)

        var walls := Node3D.new()
        walls.name = "Walls"
        _visuals.add_child(walls)

        _wall_nodes.clear()
        for i in range(4):
                var wall_holder := Node3D.new()
                wall_holder.name = "Wall_%d" % i
                walls.add_child(wall_holder)
                _wall_nodes.append(wall_holder)

        _initialized = true

func _rebuild() -> void:
        if not _initialized:
                return
        _clear_wall_segments()
        for dir in range(4):
                _build_wall(dir, _connections[dir])
        _rebuild_props()

func _create_floor() -> void:
        var floor_mesh := BoxMesh.new()
        floor_mesh.size = Vector3(cell_size, floor_thickness, cell_size)
        var floor_instance := MeshInstance3D.new()
        floor_instance.name = "Floor"
        floor_instance.mesh = floor_mesh
        floor_instance.material_override = _floor_material
        floor_instance.translation = Vector3(0, -floor_thickness * 0.5, 0)
        _visuals.add_child(floor_instance)

        var floor_shape := BoxShape3D.new()
        floor_shape.size = floor_mesh.size
        var floor_collision := CollisionShape3D.new()
        floor_collision.shape = floor_shape
        floor_collision.translation = floor_instance.translation
        _collider.add_child(floor_collision)

func _create_ceiling() -> void:
        var ceiling_mesh := BoxMesh.new()
        ceiling_mesh.size = Vector3(cell_size, ceiling_thickness, cell_size)
        var ceiling_instance := MeshInstance3D.new()
        ceiling_instance.name = "Ceiling"
        ceiling_instance.mesh = ceiling_mesh
        ceiling_instance.material_override = _ceiling_material
        ceiling_instance.translation = Vector3(0, wall_height - ceiling_thickness * 0.5, 0)
        _visuals.add_child(ceiling_instance)

func _create_trim() -> void:
        var trim_parent := Node3D.new()
        trim_parent.name = "Trim"
        _visuals.add_child(trim_parent)
        var trim_thickness := trim_size * 0.6
        var trim_height := trim_size

        var segments := [
                {"size": Vector3(cell_size, trim_height, trim_thickness), "position": Vector3(0, trim_height * 0.5, -cell_size * 0.5 + trim_thickness * 0.5)},
                {"size": Vector3(cell_size, trim_height, trim_thickness), "position": Vector3(0, trim_height * 0.5, cell_size * 0.5 - trim_thickness * 0.5)},
                {"size": Vector3(trim_thickness, trim_height, cell_size), "position": Vector3(cell_size * 0.5 - trim_thickness * 0.5, trim_height * 0.5, 0)},
                {"size": Vector3(trim_thickness, trim_height, cell_size), "position": Vector3(-cell_size * 0.5 + trim_thickness * 0.5, trim_height * 0.5, 0)}
        ]

        for segment in segments:
                var mesh := BoxMesh.new()
                mesh.size = segment["size"]
                var instance := MeshInstance3D.new()
                instance.mesh = mesh
                instance.material_override = _door_trim_material
                instance.translation = segment["position"]
                trim_parent.add_child(instance)

func _create_light() -> void:
        var light := OmniLight3D.new()
        light.name = "CeilingLight"
        light.light_color = Color(1.0, 0.95, 0.85)
        light.light_energy = 3.0
        light.omni_range = cell_size * 1.2
        light.translation = Vector3(0, light_height, 0)
        add_child(light)
        _light = light

        var lamp_mesh := CylinderMesh.new()
        lamp_mesh.top_radius = 0.12
        lamp_mesh.bottom_radius = 0.35
        lamp_mesh.height = 0.25
        _lamp_material = StandardMaterial3D.new()
        _lamp_material.albedo_color = Color(0.94, 0.9, 0.78)
        _lamp_material.roughness = 0.4

        var lamp_instance := MeshInstance3D.new()
        lamp_instance.name = "LampShade"
        lamp_instance.mesh = lamp_mesh
        lamp_instance.material_override = _lamp_material
        lamp_instance.translation = Vector3(0, light_height - lamp_mesh.height * 0.5, 0)
        add_child(lamp_instance)
        _lamp_instance = lamp_instance

func _apply_style() -> void:
        if _wall_material == null:
                return
        var rng := RandomNumberGenerator.new()
        var seed_value := _style_seed
        if seed_value == 0:
                seed_value = randi()
        rng.seed = abs(seed_value)

        var wallpaper_colors := [
                Color(0.84, 0.8, 0.74),
                Color(0.78, 0.79, 0.82),
                Color(0.87, 0.83, 0.76),
                Color(0.81, 0.77, 0.72)
        ]
        var trim_colors := [
                Color(0.6, 0.55, 0.48),
                Color(0.52, 0.46, 0.42),
                Color(0.66, 0.6, 0.53)
        ]
        var floor_colors := [
                Color(0.34, 0.26, 0.19),
                Color(0.41, 0.3, 0.2),
                Color(0.29, 0.22, 0.17)
        ]
        var lamp_colors := [
                Color(0.95, 0.9, 0.78),
                Color(0.9, 0.86, 0.74),
                Color(0.96, 0.92, 0.81)
        ]

        _wall_material.albedo_color = wallpaper_colors[rng.randi_range(0, wallpaper_colors.size() - 1)]
        _door_trim_material.albedo_color = trim_colors[rng.randi_range(0, trim_colors.size() - 1)]
        _floor_material.albedo_color = floor_colors[rng.randi_range(0, floor_colors.size() - 1)]
        if _ceiling_material != null:
                _ceiling_material.albedo_color = Color(0.93, 0.94, 0.95)
        if _lamp_material != null:
                _lamp_material.albedo_color = lamp_colors[rng.randi_range(0, lamp_colors.size() - 1)]
        if _light != null:
                var warmth := 0.9 + rng.randf() * 0.08
                _light.light_color = Color(1.0, warmth, 0.82 + rng.randf() * 0.1)
                _light.light_energy = 2.6 + rng.randf() * 0.6

func _clear_wall_segments() -> void:
        for wall in _wall_nodes:
                for child in wall.get_children():
                        child.queue_free()
        for collider_child in _collider.get_children():
                if collider_child is CollisionShape3D and collider_child.name.begins_with("WallCollision"):
                        collider_child.queue_free()

func _rebuild_props() -> void:
        if _props_container == null:
                return
        for child in _props_container.get_children():
                child.queue_free()
        var layout_seed := 0
        for dir in range(_connections.size()):
                layout_seed = layout_seed * 2 + (_connections[dir] ? 1 : 0)
        var rng := RandomNumberGenerator.new()
        var combined_seed := _style_seed * 7919 + layout_seed * 103 + 17
        if combined_seed == 0:
                combined_seed = randi()
        rng.seed = abs(combined_seed)
        if rng.randf() < 0.5:
                _add_radiator(rng)
        if rng.randf() < 0.35:
                _add_ceiling_pipe(rng)
        if rng.randf() < 0.3:
                _add_sign(rng)

func _add_radiator(rng: RandomNumberGenerator) -> void:
        var closed_dirs: Array = []
        for dir in range(_connections.size()):
                if not _connections[dir]:
                        closed_dirs.append(dir)
        if closed_dirs.is_empty():
                closed_dirs = [Direction.NORTH, Direction.EAST, Direction.SOUTH, Direction.WEST]
        var direction := closed_dirs[rng.randi_range(0, closed_dirs.size() - 1)]
        var radiator_mesh := BoxMesh.new()
        radiator_mesh.size = Vector3(1.4, 0.6, 0.25)
        var radiator := MeshInstance3D.new()
        radiator.mesh = radiator_mesh
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.86, 0.87, 0.88)
        material.roughness = 0.8
        radiator.material_override = material
        var position := _wall_position(direction, 0.35, wall_thickness * 0.5 + 0.12)
        var lateral_offset := rng.randf_range(-cell_size * 0.25, cell_size * 0.25)
        position += _lateral_direction(direction) * lateral_offset
        radiator.translation = position
        radiator.rotation = Vector3(0, _direction_to_rotation(direction), 0)
        _props_container.add_child(radiator)

        if rng.randf() < 0.7:
                var pipe_mesh := CylinderMesh.new()
                pipe_mesh.top_radius = 0.05
                pipe_mesh.bottom_radius = 0.05
                pipe_mesh.height = 1.0
                var pipe := MeshInstance3D.new()
                pipe.mesh = pipe_mesh
                var pipe_material := StandardMaterial3D.new()
                pipe_material.albedo_color = Color(0.74, 0.72, 0.68)
                pipe_material.roughness = 0.6
                pipe.material_override = pipe_material
                pipe.translation = position + Vector3(0, 0.5, 0) + _normal_direction(direction) * 0.05
                _props_container.add_child(pipe)

func _add_ceiling_pipe(rng: RandomNumberGenerator) -> void:
        var pipe_mesh := CylinderMesh.new()
        pipe_mesh.top_radius = 0.04
        pipe_mesh.bottom_radius = 0.04
        pipe_mesh.height = cell_size - wall_thickness * 2.0
        var pipe := MeshInstance3D.new()
        pipe.mesh = pipe_mesh
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.63, 0.61, 0.58)
        material.metallic = 0.15
        material.roughness = 0.5
        pipe.material_override = material
        var height := wall_height - 0.35
        var orientation := rng.randi_range(0, 1)
        if orientation == 0:
                pipe.rotation = Vector3(0, 0, PI * 0.5)
                var side := (rng.randf() < 0.5 ? -1 : 1)
                pipe.translation = Vector3(0, height, side * (cell_size * 0.5 - 0.45))
        else:
                pipe.rotation = Vector3(PI * 0.5, 0, 0)
                var side := (rng.randf() < 0.5 ? -1 : 1)
                pipe.translation = Vector3(side * (cell_size * 0.5 - 0.45), height, 0)
        _props_container.add_child(pipe)

func _add_sign(rng: RandomNumberGenerator) -> void:
        var open_dirs: Array = []
        for dir in range(_connections.size()):
                if _connections[dir]:
                        open_dirs.append(dir)
        if open_dirs.is_empty():
                open_dirs = [Direction.NORTH, Direction.EAST, Direction.SOUTH, Direction.WEST]
        var direction := open_dirs[rng.randi_range(0, open_dirs.size() - 1)]
        var sign_mesh := BoxMesh.new()
        sign_mesh.size = Vector3(1.1, 0.35, 0.05)
        var sign := MeshInstance3D.new()
        sign.mesh = sign_mesh
        var sign_material := StandardMaterial3D.new()
        sign_material.albedo_color = Color(0.6, 0.74, 0.65)
        sign_material.emission_enabled = true
        sign_material.emission = Color(0.45, 0.62, 0.53)
        sign_material.emission_energy_multiplier = 0.3
        sign_material.roughness = 0.45
        sign.material_override = sign_material
        var position := _wall_position(direction, 1.6, wall_thickness * 0.5 + 0.04)
        position += _lateral_direction(direction) * rng.randf_range(-cell_size * 0.2, cell_size * 0.2)
        sign.translation = position
        sign.rotation = Vector3(0, _direction_to_rotation(direction), 0)
        _props_container.add_child(sign)

func _build_wall(direction: int, has_door: bool) -> void:
        var wall_parent := _wall_nodes[direction]
        var offset := Vector3.ZERO
        var rotation := Vector3.ZERO

        match direction:
                Direction.NORTH:
                        offset = Vector3(0, wall_height * 0.5, -cell_size * 0.5 + wall_thickness * 0.5)
                Direction.SOUTH:
                        offset = Vector3(0, wall_height * 0.5, cell_size * 0.5 - wall_thickness * 0.5)
                        rotation = Vector3(0, PI, 0)
                Direction.EAST:
                        offset = Vector3(cell_size * 0.5 - wall_thickness * 0.5, wall_height * 0.5, 0)
                        rotation = Vector3(0, PI * 0.5, 0)
                Direction.WEST:
                        offset = Vector3(-cell_size * 0.5 + wall_thickness * 0.5, wall_height * 0.5, 0)
                        rotation = Vector3(0, -PI * 0.5, 0)

        if has_door:
                        _build_wall_with_door(wall_parent, offset, rotation, direction)
        else:
                        _build_full_wall(wall_parent, offset, rotation, direction)

func _build_wall_with_door(parent: Node3D, offset: Vector3, rotation: Vector3, direction: int) -> void:
        var segment_width := (cell_size - door_width) * 0.5
        var segments := [Vector3(-door_width * 0.5 - segment_width * 0.5, 0, 0), Vector3(door_width * 0.5 + segment_width * 0.5, 0, 0)]
        for i in range(segments.size()):
                var pos_offset := segments[i]
                var mesh_size := Vector3(segment_width, wall_height, wall_thickness)
                _create_wall_segment(parent, offset + _rotate_vector(pos_offset, rotation), rotation, mesh_size, direction, i)

        var lintel_size := Vector3(door_width, wall_height - door_height, wall_thickness)
        var lintel_position := offset + _rotate_vector(Vector3(0, door_height + lintel_size.y * 0.5 - wall_height * 0.5, 0), rotation)
        _create_wall_segment(parent, lintel_position, rotation, lintel_size, direction, 2)

        var trim_height := door_height + 0.2
        var trim_width := door_width + 0.2
        var trim_mesh := BoxMesh.new()
        trim_mesh.size = Vector3(trim_width, trim_height, trim_size)
        var trim_instance := MeshInstance3D.new()
        trim_instance.mesh = trim_mesh
        trim_instance.material_override = _door_trim_material
        trim_instance.translation = offset + _rotate_vector(Vector3(0, trim_height * 0.5 - wall_height * 0.5, wall_thickness * 0.5 + trim_size * 0.5), rotation)
        trim_instance.rotation = rotation
        parent.add_child(trim_instance)

func _build_full_wall(parent: Node3D, offset: Vector3, rotation: Vector3, direction: int) -> void:
        var mesh_size := Vector3(cell_size, wall_height, wall_thickness)
        _create_wall_segment(parent, offset, rotation, mesh_size, direction, 0)

func _create_wall_segment(parent: Node3D, position: Vector3, rotation: Vector3, size: Vector3, direction: int, segment_index: int) -> void:
        var mesh := BoxMesh.new()
        mesh.size = size
        var instance := MeshInstance3D.new()
        instance.mesh = mesh
        instance.material_override = _wall_material
        instance.translation = position
        instance.rotation = rotation
        parent.add_child(instance)

        var shape := BoxShape3D.new()
        shape.size = size
        var collision := CollisionShape3D.new()
        collision.name = "WallCollision_%d_%d" % [direction, segment_index]
        collision.shape = shape
        collision.translation = position
        collision.rotation = rotation
        _collider.add_child(collision)

func _rotate_vector(vec: Vector3, rotation: Vector3) -> Vector3:
        var basis := Basis.IDENTITY
        basis = basis.rotated(Vector3.UP, rotation.y)
        return basis * vec

func _direction_to_rotation(direction: int) -> float:
        match direction:
                Direction.NORTH:
                        return 0.0
                Direction.EAST:
                        return PI * 0.5
                Direction.SOUTH:
                        return PI
                Direction.WEST:
                        return -PI * 0.5
        return 0.0

func _wall_position(direction: int, height: float, inset: float) -> Vector3:
        match direction:
                Direction.NORTH:
                        return Vector3(0, height, -cell_size * 0.5 + inset)
                Direction.SOUTH:
                        return Vector3(0, height, cell_size * 0.5 - inset)
                Direction.EAST:
                        return Vector3(cell_size * 0.5 - inset, height, 0)
                Direction.WEST:
                        return Vector3(-cell_size * 0.5 + inset, height, 0)
        return Vector3.ZERO

func _lateral_direction(direction: int) -> Vector3:
        match direction:
                Direction.NORTH, Direction.SOUTH:
                        return Vector3(1, 0, 0)
                Direction.EAST, Direction.WEST:
                        return Vector3(0, 0, 1)
        return Vector3.ZERO

func _normal_direction(direction: int) -> Vector3:
        match direction:
                Direction.NORTH:
                        return Vector3(0, 0, 1)
                Direction.SOUTH:
                        return Vector3(0, 0, -1)
                Direction.EAST:
                        return Vector3(-1, 0, 0)
                Direction.WEST:
                        return Vector3(1, 0, 0)
        return Vector3.ZERO
