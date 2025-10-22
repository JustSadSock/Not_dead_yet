extends Node3D

@export var cell_scene: PackedScene
@export var player_path: NodePath
@export var cell_size: float = 10.0
@export var load_distance: int = 2
@export var unload_distance: int = 4
@export var update_interval: float = 0.5
@export var world_seed: int = 1337

const DIR_VECTORS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var _player: Node3D
var _time_accumulator: float = 0.0
var _cells: Dictionary = {}
var _pending_connections: Dictionary = {}
var _last_player_cell := Vector2i(2147483647, 2147483647)

func _ready() -> void:
        if load_distance < 1:
                load_distance = 1
        if unload_distance <= load_distance:
                unload_distance = load_distance + 1
        _player = get_node_or_null(player_path)
        if _player == null:
                push_warning("ApartmentGenerator could not find a player at path %s" % player_path)
                return
        _update_generation(true)

func _physics_process(delta: float) -> void:
        _time_accumulator += delta
        if _time_accumulator < update_interval:
                return
        _time_accumulator = 0.0
        _update_generation(false)

func _update_generation(force: bool) -> void:
        if _player == null:
                return
        var current_cell := _world_to_cell(_player.global_position)
        if not force and current_cell == _last_player_cell:
                return
        _last_player_cell = current_cell
        _ensure_cells_around(current_cell)
        _cleanup_distant_cells(current_cell)

func _ensure_cells_around(center: Vector2i) -> void:
        for x in range(center.x - load_distance, center.x + load_distance + 1):
                for y in range(center.y - load_distance, center.y + load_distance + 1):
                        var coord := Vector2i(x, y)
                        if not _cells.has(coord):
                                _create_cell(coord)

func _cleanup_distant_cells(center: Vector2i) -> void:
        var to_remove: Array = []
        for coord in _cells.keys():
                        if _distance_metric(coord, center) > unload_distance:
                                to_remove.append(coord)
        for coord in to_remove:
                var data: Dictionary = _cells.get(coord, {})
                if data.has("node"):
                        var node: Node = data.get("node", null)
                        if node != null:
                                node.queue_free()
                _cells.erase(coord)
                _pending_connections.erase(coord)

func _create_cell(coord: Vector2i) -> void:
        if cell_scene == null:
                push_warning("ApartmentGenerator is missing a cell_scene reference.")
                return
        var connections: Array[bool] = [false, false, false, false]
        if _pending_connections.has(coord):
                for dir in _pending_connections[coord]:
                        connections[dir] = true
                _pending_connections.erase(coord)
        var rng := RandomNumberGenerator.new()
        rng.seed = _coordinate_seed(coord)
        var roll := rng.randf()
        var desired_openings := 2
        if roll < 0.25:
                desired_openings = 1
        elif roll < 0.65:
                desired_openings = 2
        elif roll < 0.9:
                desired_openings = 3
        else:
                desired_openings = 4
        var connection_count := 0
        for dir in range(connections.size()):
                if connections[dir]:
                        connection_count += 1
        var directions := [0, 1, 2, 3]
        directions.shuffle()
        for dir in directions:
                if connection_count >= desired_openings:
                        break
                if connections[dir]:
                        continue
                if rng.randf() < 0.65:
                        connections[dir] = true
                        connection_count += 1
        if connection_count < desired_openings:
                var remaining: Array = []
                for dir in range(connections.size()):
                        if not connections[dir]:
                                remaining.append(dir)
                while connection_count < desired_openings and not remaining.is_empty():
                        var idx := rng.randi_range(0, remaining.size() - 1)
                        var forced_dir: int = remaining[idx]
                        remaining.remove_at(idx)
                        connections[forced_dir] = true
                        connection_count += 1
        if connection_count == 0:
                var fallback_dir := rng.randi_range(0, 3)
                connections[fallback_dir] = true
                connection_count = 1
        for dir in range(connections.size()):
                if not connections[dir]:
                        continue
                var neighbor_coord: Vector2i = coord + DIR_VECTORS[dir]
                var opposite := _opposite_direction(dir)
                if _cells.has(neighbor_coord):
                        _update_cell_connection(neighbor_coord, opposite, true)
                else:
                        _queue_pending_connection(neighbor_coord, opposite)
        var instance := cell_scene.instantiate()
        if not (instance is Node3D):
                push_error("Apartment cell scene must inherit from Node3D.")
                return
        instance.name = "Cell_%d_%d" % [coord.x, coord.y]
        var script := instance.get_script()
        if instance is ApartmentCell:
                instance.cell_size = cell_size
                instance.set_style_seed(_coordinate_seed(coord) * 17)
        elif script != null:
                instance.set("cell_size", cell_size)
                if instance.has_method("set_style_seed"):
                        instance.call("set_style_seed", _coordinate_seed(coord) * 17)
        add_child(instance)
        instance.global_position = Vector3(coord.x * cell_size, 0, coord.y * cell_size)
        if instance.has_method("set_connections"):
                instance.call_deferred("set_connections", connections.duplicate())
        _cells[coord] = {
                "node": instance,
                "connections": connections
        }

func _queue_pending_connection(coord: Vector2i, direction: int) -> void:
        if not _pending_connections.has(coord):
                _pending_connections[coord] = []
        var list: Array[int] = _pending_connections[coord]
        if direction not in list:
                list.append(direction)

func _update_cell_connection(coord: Vector2i, direction: int, enabled: bool) -> void:
        if not _cells.has(coord):
                if enabled:
                        _queue_pending_connection(coord, direction)
                return
        var data: Dictionary = _cells[coord]
        var connections: Array[bool] = data["connections"]
        if connections[direction] == enabled:
                return
        connections[direction] = enabled
        var node: Node = data.get("node", null)
        if node != null:
                if node.has_method("set_connection"):
                        node.call_deferred("set_connection", direction, enabled)

func _world_to_cell(world_position: Vector3) -> Vector2i:
        return Vector2i(int(round(world_position.x / cell_size)), int(round(world_position.z / cell_size)))

func _distance_metric(a: Vector2i, b: Vector2i) -> int:
        return max(abs(a.x - b.x), abs(a.y - b.y))

func _opposite_direction(direction: int) -> int:
        return (direction + 2) % 4

func _coordinate_seed(coord: Vector2i) -> int:
        var value := int(coord.x * 92837111 + coord.y * 689287499 + world_seed * 73)
        return abs(value)
