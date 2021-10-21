extends ColorRect

const LINE_WIDTH = 4.0

func _ready():
	pass # Replace with function body.

func _draw():
	draw_line(Vector2(0, 96), Vector2(288, 96), Color.black, LINE_WIDTH)
	draw_line(Vector2(0, 192), Vector2(288, 192), Color.black, LINE_WIDTH)
	draw_line(Vector2(96, 0), Vector2(96, 288), Color.black, LINE_WIDTH)
	draw_line(Vector2(192, 0), Vector2(192, 288), Color.black, LINE_WIDTH)
