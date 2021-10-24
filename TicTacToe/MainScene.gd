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
enum {
	MODE_NONE = 0,
	MODE_RAND_RAND,
	MODE_AI_RAND,		# AI vs Rand 非学習
	MODE_AI_AI,			# AI 自己対戦学習
}
var mode = MODE_NONE
var nEpisode = 0
var nEpisodeRest = 0
var nOwon = 0			# O 勝数
var nXwon = 0			# X 勝数
var nAIwon = 0			# AI 勝数
var nRANDwon = 0			# RAND 勝数
var nDraw = 0			# 引き分け数
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
	#print("make_Q(%d)" % qix)
	if Q[qix] != null: return
	Q[qix] = []
	var empty = ~(bits_O | bits_X)		# 1 for EMPTY
	var mask = 1
	if next == TILE_O:		# O の手番
		for i in range(9):
			Q[qix].push_back(1.0 if (empty&mask) != 0 else -9.999)
			mask <<= 1
	else:					# X の手番
		for i in range(9):
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
func is_draw():
	return (bits_O | bits_X) == ALL_BITS
func update_nextLabel():
	if is_victory_table[bits_O]:
		$NextLabel.text = "O won"
	elif is_victory_table[bits_X]:
		$NextLabel.text = "X won"
	elif is_draw():		# 引き分け？
		$NextLabel.text = "draw"
	elif next == TILE_O:
		$NextLabel.text = "Next: O"
	else:
		$NextLabel.text = "Next: X"
		
func _input(event):
	if event is InputEventMouseButton && event.is_pressed():	# マウスクリックイベント
		if is_victory_table[bits_O] || is_victory_table[bits_O] || is_draw():
			init_board()
		else:
			var pos = $Board/TileMap.get_local_mouse_position()
			var map = $Board/TileMap.world_to_map(pos)
			#print(map)
			if map.x < 0 || map.x >= N_HORZ || map.y < 0 || map.y >= N_VERT: return
			set_cell(map.x, map.y, next)
			next = (TILE_O + TILE_X) - next			# 手番交代
		update_qvLabels()		# Q値表示
		update_nextLabel()		# 次の手番ラベル更新
		
func get_empty_list():	# 空欄箇所リストを返す
	var lst = []
	var ix = 0
	for y in N_VERT:
		for x in N_HORZ:
			if $Board/TileMap.get_cell(x, y) == TILE_EMPTY:
				lst.push_back(ix)
			ix += 1
	return lst
func modeRandRand():
	nEpisode += 1
	$EpiNumLabel.text = "#%d" % nEpisode
	init_board()
	while true:
		var lst = get_empty_list()
		var ix = lst[rng.randi_range(0, lst.size() - 1)]
		var t = ix_to_xy(ix)
		set_cell(t[0], t[1], next)
		next = (TILE_O + TILE_X) - next			# 手番交代
		if is_victory_table[bits_O]:
			nOwon += 1
			break;
		elif is_victory_table[bits_X]:
			nXwon += 1
			break;
		elif is_draw():
			nDraw += 1
			break;
	update_nextLabel()
	update_qvLabels()
	nEpisodeRest -= 1
	if !nEpisodeRest:
		mode = MODE_NONE
		print("\nnOwon = %d (%.1f%%)" % [nOwon, nOwon * 100.0/nEpisode])
		print("nXwon = %d (%.1f%%)" % [nXwon, nXwon * 100.0/nEpisode])
		print("nDraw = %d (%.1f%%)" % [nDraw, nDraw * 100.0/nEpisode])
func nextMove(qix):
	var empty = ~(bits_O | bits_X)		# 1 for EMPTY
	var lst = []
	var mask = 1
	if next == TILE_O:		# O の手番、最大Q値の行動を選択
		var maxq = -9
		for i in range(Q[qix].size()):
			if (empty & mask) != 0:
				if Q[qix][i] > maxq:
					lst = [i]
					maxq = Q[qix][i]
				elif Q[qix][i] == maxq:
					lst.push_back(i)
			mask <<= 1
	else:					# X の手番、最小Q値の行動を選択
		var minq = 9
		for i in range(Q[qix].size()):
			if (empty & mask) != 0:
				if Q[qix][i] < minq:
					lst = [i]
					minq = Q[qix][i]
				elif Q[qix][i] == minq:
					lst.push_back(i)
			mask <<= 1
	assert( !lst.empty() )
	if lst.size() == 1:
		return lst[0]
	else:
		return lst[rng.randi_range(0, lst.size() - 1)]
func modeAiRand():		# AI vs RAND、学習あり
	nEpisode += 1
	# nEpisode が奇数の場合は AI が先手（O）、偶数であれば AIが後手（X）
	$EpiNumLabel.text = "#%d" % nEpisode
	init_board()
	var AIturn : bool = (nEpisode & 1) != 0
	while true:
		var qix = bb_to_qix(bits_O, bits_X)
		make_Q(qix)
		var ix
		if AIturn:
			ix = nextMove(qix)
		else:
			var lst = get_empty_list()
			ix = lst[rng.randi_range(0, lst.size() - 1)]
		var t = ix_to_xy(ix)
		set_cell(t[0], t[1], next)
		next = (TILE_O + TILE_X) - next			# 手番交代
		AIturn = !AIturn
		var reward = 0.0
		var ef = false
		if is_victory_table[bits_O]:
			#nOwon += 1
			if (nEpisode & 1) != 0:		# AI が先手（O）
				nAIwon += 1
			else:
				nRANDwon += 1
			reward = 1.0
			ef = true
			#break;
		elif is_victory_table[bits_X]:
			#nXwon += 1
			if (nEpisode & 1) == 0:		# AI が後手（X）
				nAIwon += 1
			else:
				nRANDwon += 1
			reward = -1.0
			ef = true
			#break;
		elif is_draw():
			nDraw += 1
			ef = true
			#break;
		var qix2 = bb_to_qix(bits_O, bits_X)
		make_Q(qix2)
		var minmaxQ = 0.0
		if !ef:
			if next == TILE_O:
				minmaxQ = Q[qix2].max()
			else:
				minmaxQ = Q[qix2].min()
		Q[qix][ix] += ALPHA * (reward + GAMMA * minmaxQ - Q[qix][ix])
		if ef: break
	update_nextLabel()
	update_qvLabels()
	nEpisodeRest -= 1
	if !nEpisodeRest:
		mode = MODE_NONE
		print("\nnAIwon = %d (%.1f%%)" % [nAIwon, nAIwon * 100.0/nEpisode])
		print("nRANDwon = %d (%.1f%%)" % [nRANDwon, nRANDwon * 100.0/nEpisode])
		print("nDraw = %d (%.1f%%)" % [nDraw, nDraw * 100.0/nEpisode])
func modeAiAi():
	nEpisode += 1
	$EpiNumLabel.text = "#%d" % nEpisode
	init_board()
	while true:
		var ef = false		# 終局フラグ
		var qix = bb_to_qix(bits_O, bits_X)
		make_Q(qix)
		var ix = nextMove(qix)
		var t = ix_to_xy(ix)
		set_cell(t[0], t[1], next)
		next = (TILE_O + TILE_X) - next			# 手番交代
		var reward = 0.0
		if is_victory_table[bits_O]:
			nOwon += 1
			reward = 1.0
			ef = true
		elif is_victory_table[bits_X]:
			nXwon += 1
			reward = -1.0
			ef = true
		elif is_draw():
			nDraw += 1
			ef = true
		var qix2 = bb_to_qix(bits_O, bits_X)
		make_Q(qix2)
		var minmaxQ = 0.0
		if !ef:
			if next == TILE_O:
				minmaxQ = Q[qix2].max()
			else:
				minmaxQ = Q[qix2].min()
		Q[qix][ix] += ALPHA * (reward + GAMMA * minmaxQ - Q[qix][ix])
		if ef: break
	update_nextLabel()
	update_qvLabels()
	nEpisodeRest -= 1
	if !nEpisodeRest:
		mode = MODE_NONE
		print("\nnOwon = %d (%.1f%%)" % [nOwon, nOwon * 100.0/nEpisode])
		print("nXwon = %d (%.1f%%)" % [nXwon, nXwon * 100.0/nEpisode])
		print("nDraw = %d (%.1f%%)" % [nDraw, nDraw * 100.0/nEpisode])
func _process(delta):
	if mode == MODE_RAND_RAND:
		modeRandRand()
	elif mode == MODE_AI_RAND:
		modeAiRand()
	elif mode == MODE_AI_AI:
		modeAiAi()
	pass


func _on_RxRx100Button_pressed():
	nEpisode = 0
	nEpisodeRest = 100
	nOwon = 0
	nXwon = 0
	nDraw = 0
	mode = MODE_RAND_RAND
	pass


func _on_AIxAIx100Button_pressed():
	nEpisode = 0
	nEpisodeRest = 100
	nOwon = 0
	nXwon = 0
	nDraw = 0
	mode = MODE_AI_AI
	pass # Replace with function body.


func _on_AIxRx100Button_pressed():
	nEpisode = 0
	nEpisodeRest = 100
	nAIwon = 0
	nRANDwon = 0
	nDraw = 0
	mode = MODE_AI_RAND
	pass # Replace with function body.
