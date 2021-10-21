extends Node2D

const ALPHA = 0.2
const GAMMA = 0.99
const N_HORZ = 3
const N_VERT = 3
const CELL_WIDTH = 96
const N_2_POWER_9 = 512			# 2^9
const N_3_POWER_9 = 19683		# 3^9
const ALL_BITS = (1<<9) - 1		# 盤面全体
enum {
	TILE_EMPTY = -1,
	TILE_O,
	TILE_X,
}
var started = false
var ended = false		# 終局状態
var next				# TILE_O or TILE_X
var bits_O = 0			# O 状態ビットボード
var bits_X = 0			# X 状態ビットボード

func _ready():
	init_board()
	pass # Replace with function body.
func init_board():
	ended = false
	next = TILE_O
	#moved = []
	bits_O = 0
	bits_X = 0
	for y in N_VERT:
		for x in N_HORZ:
			$Board/TileMap.set_cell(x, y, TILE_EMPTY)
func set_cell(x : int, y : int, v : int):
	$Board/TileMap.set_cell(x, y, v)
	var mask = 1 << (y*N_HORZ + x)
	if v == TILE_O:
		bits_O |= mask
	else:
		bits_X |= mask
func _input(event):
	if event is InputEventMouseButton && event.is_pressed():
		var pos = $Board/TileMap.get_local_mouse_position()
		var map = $Board/TileMap.world_to_map(pos)
		print(map)
		if map.x < 0 || map.x >= N_HORZ || map.y < 0 || map.y >= N_VERT: return
		set_cell(map.x, map.y, next)
		next = (TILE_O + TILE_X) - next			# 手番交代
		
func _process(delta):
	pass
