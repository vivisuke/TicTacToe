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
var is_victory_table = []		# ビットボード → ３目並びがあるか？
var Q = []				# Q値テーブル
var qvalLabel = []		# Q値表示用ラベル
var rng = RandomNumberGenerator.new()

var QValLabel = load("res://QValLabel.tscn")

func _ready():
	Q.resize(N_3_POWER_9)		# 全状態：3^9
	build_victory_table()
	init_board()
	init_qvlabels()			# Q値表示用ラベル初期化
	update_qvLabels()		# Q値表示
	update_nextLabel()		# 次の手番ラベル更新
	pass
func init_board():
	ended = false
	next = TILE_O
	#moved = []
	bits_O = 0
	bits_X = 0
	for y in N_VERT:
		for x in N_HORZ:
			$Board/TileMap.set_cell(x, y, TILE_EMPTY)
func init_qvlabels():
	for y in range(N_VERT):
		for x in range(N_HORZ):
			var label = QValLabel.instance()
			label.rect_position = Vector2(x*CELL_WIDTH+4, y*CELL_WIDTH) + $Board.rect_position
			add_child(label)
			qvalLabel.push_back(label)
func make_Q(qix):
	print("make_Q(%d)" % qix)
	if Q[qix] != null: return
	Q[qix] = []
	var empty = ~(bits_O | bits_X)		# 1 for EMPTY
	var mask = 1
	for i in range(9):
		if next == TILE_O:		# O の手番
			Q[qix].push_back(1.0 if (empty&mask) != 0 else -9.999)
		else:					# X の手番
			Q[qix].push_back(-1.0 if (empty&mask) != 0 else 9.999)
		mask <<= 1
func update_qvLabels():		# 現状態の各行動のQ値を表示
	var qix = bb_to_qix(bits_O, bits_X)
	make_Q(qix)
	var mask = 1
	var empty = ~(bits_O | bits_X)		# 1 for EMPTY
	for i in range(9):
		if (empty & mask) == 0:
			qvalLabel[i].text = ""
		else:
			qvalLabel[i].text = "%.3f" % Q[qix][i]
		mask <<= 1
func bb_to_qix(bO, bX):
	var qix = 0
	var mask = 1 << 8
	while mask != 0:
		qix *= 3
		if (bO & mask) != 0:
			qix += 1
		elif (bX & mask) != 0:
			qix += 2
		mask >>= 1
	return qix
func ix_to_xy(ix : int):
	return [ix % N_HORZ, ix / N_HORZ]
func set_cell(x : int, y : int, v : int):
	$Board/TileMap.set_cell(x, y, v)
	var mask = 1 << (y*N_HORZ + x)
	if v == TILE_O:
		bits_O |= mask
	else:
		bits_X |= mask
func is_victory_basic(bits) -> bool:	# 勝利状態か？
	if (bits & 0b111000000) == 0b111000000: return true
	if (bits & 0b000111000) == 0b000111000: return true
	if (bits & 0b000000111) == 0b000000111: return true
	if (bits & 0b100100100) == 0b100100100: return true
	if (bits & 0b010010010) == 0b010010010: return true
	if (bits & 0b001001001) == 0b001001001: return true
	if (bits & 0b100010001) == 0b100010001: return true
	if (bits & 0b001010100) == 0b001010100: return true
	return false
func build_victory_table():
	is_victory_table.resize(N_2_POWER_9)
	for bits in range(N_2_POWER_9):
		is_victory_table[bits] = is_victory_basic(bits)
func update_nextLabel():
	if is_victory_table[bits_O]:
		$NextLabel.text = "O won"
	elif is_victory_table[bits_X]:
		$NextLabel.text = "X won"
	elif (bits_O | bits_X) == ALL_BITS:
		$NextLabel.text = "draw"
	elif next == TILE_O:
		$NextLabel.text = "Next: O"
	else:
		$NextLabel.text = "Next: X"
		
func _input(event):
	if event is InputEventMouseButton && event.is_pressed():	# マウスクリックイベント
		if is_victory_table[bits_O] || is_victory_table[bits_O] || (bits_O | bits_X) == ALL_BITS:
			init_board()
		else:
			var pos = $Board/TileMap.get_local_mouse_position()
			var map = $Board/TileMap.world_to_map(pos)
			print(map)
			if map.x < 0 || map.x >= N_HORZ || map.y < 0 || map.y >= N_VERT: return
			set_cell(map.x, map.y, next)
			next = (TILE_O + TILE_X) - next			# 手番交代
		update_qvLabels()		# Q値表示
		update_nextLabel()		# 次の手番ラベル更新
		
func _process(delta):
	pass
