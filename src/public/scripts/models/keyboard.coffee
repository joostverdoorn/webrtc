define [], ( ) ->
	class Keyboard
		@Keys:
			BACKSPACE:		8
			TAB:			9
			RETURN:			13
			SHIFT:			16
			CONTROL:		17
			PAUSE:			19
			CAPSLOCK:		20
			ESCAPE:			27
			SPACE:			32
			PAGEUP:			33
			PAGEDOWN:		34
			END:			35
			HOME:			36
			LEFT:			37
			UP:				38
			RIGHT:			39
			DOWN:			40
			INSERT:			45
			DELETE:			46
			NUMLOCK:		144
			NUM_MULTIPLY:	106
			NUM_PLUS:		107
			NUM_ENTER:		108
			NUM_MINUS:		109
			NUM_DECIMAL:	110
			NUM_DIVIDE:		111

		alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
		numbers = '0123456789'

		@Keys[letter] = (alphabet + numbers).charCodeAt(i) for i, letter of alphabet + numbers

		# NumPad numbers start 48 higher than "normal" numbers
		@Keys["NUM_#{letter}"] = numbers.charCodeAt(i) + 48 for i, letter of numbers