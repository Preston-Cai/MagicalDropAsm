################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Magical Drop.
#
# Student 1: Preston Cai, 1012556440
# Student 2: Andrei Berzin, 1012239481
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################
.macro PUSH (%reg)
    addiu $sp, $sp, -4
    sw %reg, 0($sp)
.end_macro

.macro POP (%reg)
    lw %reg, 0($sp)
    addiu $sp, $sp, 4
.end_macro

##############################################################################
    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000
    
COLOR_MAP:  # color index: 0 is empty, 1 is red, 2 is green, 5 is white, ...
    .word 0x00000000    # empty (black)
    .word 0x00ff0000    # Red
    .word 0x0000ff00    # Green
    .word 0x000000ff    # Blue
    .word 0x00ffff00    # Yellow
    .word 0x00ffffff    # White
    .word 0x00AEA7A7    # light gray (for walls)

ADDRESS_DSPL_BOARD_START:
    .word 0x10008388   # ADDR_DSPL + (32 * 7 + 2) * 4 = 904 = 388_hex (since our board starts at (7, 2))

# Board Constants
.eqv BOARD_X 2          # board starting horizontal pos
.eqv BOARD_Y 7          # board starting vertical pos
.eqv BOARD_COLS 8       # board no. of columns
.eqv BOARD_ROWS 16      # board no. of rows
.eqv PLAYER_Y 24        # vertical pos of player head
.eqv WALL_COLOR 6       # wall color (gray)
.eqv WALL_LEFT 1        # left wall x coordinate
.eqv WALL_RIGHT 10      # right wall x coordinate
.eqv WALL_TOP 6         # top wall y coordinate
.eqv WALL_BOTTOM 23     # bottom wall y coordinate

# Row Advancement Trigger
.eqv ADVANCE_EVERY 10

##############################################################################
# Mutable Data
##############################################################################
board:  # containing colors (a byte per cell, each byte contains the color index)
    .space 128  # 8 columns, 16 rows
score:
    .word 0   # maximum score 2^32 - 1
carried_count:
    .byte 0
carried_color:  # color index only needs 1 byte
    .space 1
player_x:
    .byte 3    # position of player on the board (0-7, as there are 8 columns)
keystroke_counter:
    .byte 0    # number of keystrokes pressed so far. Resets & calls advance_row once it reaches 10.
match:
    .byte 0     # 1 or 0, whether there is a match
    .byte 0     # how many matches (0-8, 8 columns => at most 8 vertical matches formed)
    .space 24   # 3 * 8, for each: color index - 1 byte, (x, y) on board of one bubble in the match - 2 bytes

# Scoreboard letter bitmaps
# All letters are 3x5. 0 means empty (black), 5 is white.
LETTER_P:
.byte 5,5,5
.byte 5,0,5
.byte 5,5,5
.byte 5,0,0
.byte 5,0,0

LETTER_T:
.byte 5,5,5
.byte 0,5,0
.byte 0,5,0
.byte 0,5,0
.byte 0,5,0

LETTER_S:
.byte 5,5,5
.byte 5,0,0
.byte 5,5,5
.byte 0,0,5
.byte 5,5,5

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # Initialize the game
    j init

game_loop:
    # 1. check keyboard input
    jal keyboard_input
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
    jal destroy_bubbles     # find matches, destroy all connected, apply gravity, find matches, ..., until no more matches
	# 4. Sleep
	li $v0, 32
	li $a0, 16
	syscall

    # 5. Go back to Step 1
    j game_loop
    
quit:
li $v0, 10
syscall
    
init:
la $s0, COLOR_MAP   # saved constant: color map array's address
la $s1, board    # saved constant: board's memory address
lw $s2, ADDR_DSPL    # saved constant: address of bitmap display
lw $s3, ADDR_KBRD   # saved_constant: address of keyboard input
la $s4, match
jal draw_initial_board
jal paint_walls
# load & draw P at (18, 7)
la $a0, LETTER_P
li $a1, 7
li $a2, 18
jal paint_letter
# load & draw T at (22, 7)
la $a0, LETTER_T
li $a1, 7
li $a2, 22
jal paint_letter
# load & draw S at (26, 7)
la $a0, LETTER_S
li $a1, 7
li $a2, 26
jal paint_letter
jal paint_player
j game_loop

# $t0: loop index; $t1: current address
draw_initial_board:
PUSH ($ra)
add $t0, $zero, $zero
j draw_initial_board_loop

# $t0: current board index
draw_initial_board_loop:
beq $t0, 40, draw_initial_board_end   # fill first 5 rows * 8 per row
jal rand
move $a0, $v1
move $a1, $t0
jal save_color
addi $t0, $t0, 1    # next byte on the board
j draw_initial_board_loop

draw_initial_board_end:
jal paint_board
POP ($ra)
jr $ra

# check and handle keyboard press
# uses: see each case
keyboard_input:
PUSH ($ra)
lw $t1, 0($s3)
beq $t1, 1, handle_input
j handle_end

handle_input:
# increment keystroke counter
la $t0, keystroke_counter
lb $t2, 0($t0)
addi $t2, $t2, 1
sb $t2, 0($t0)
bne $t2, ADVANCE_EVERY, SKIP_ADVANCE
# reset counter to zero
sb $zero, 0($t0)
jal advance_rows
SKIP_ADVANCE:
lw $t1, 4($s3)   # which key pressed in ascii
beq $t1, 0x61, handle_left
beq $t1, 0x64, handle_right
beq $t1, 0x73, handle_grab      # key s
beq $t1, 0x77, handle_throw     # key w
beq $t1, 0x71, quit             # key q
j handle_end

# uses: $t1, $t2
handle_left:
la $t1, player_x
lb $t2, player_x
beq $t2, 0, handle_end  # cannot move further left
addi $t2, $t2, -1
sb $t2, 0($t1)
jal paint_player
j handle_end

# uses: $t1, $t2
handle_right:
la $t1, player_x
lb $t2, player_x
beq $t2, 7, handle_end  # cannot move further right
addi $t2, $t2, 1
sb $t2, 0($t1)
jal paint_player
j handle_end

# precondition: carried_count = 0
# uses: $t0-$t2, $a1, $a2, $v1
handle_grab:
lb $t0, carried_count
bne $t0, 0, handle_end
jal find_and_grab
jal paint_board
jal paint_player
j handle_end

find_and_grab:
PUSH ($ra)
lb $a2, player_x
li $a1, 15  # start searching from the bottom
j get_curr_color_loop

get_curr_color_loop:
bltz $a1, find_and_grab_end     # the entire col has no valid color
PUSH ($a1)
PUSH ($a2)
jal get_board_color
POP ($a2)
POP ($a1)
bgt $v1, 4, no_valid_color_hit
beq $v1, 0, no_valid_color_hit
j set_curr_color

no_valid_color_hit: # valid color: color index in {1, 2, 3, 4}
addi $a1, $a1, -1   # go up one cell
j get_curr_color_loop

set_curr_color:
move $t0, $v1   # $t0 keeps track of the color of the first ball grabbed
la $t1, carried_color
sb $t0, 0($t1)  # save the color carried_color
j grab_loop

grab_loop:
bltz $a1, find_and_grab_end   # end when reaching the top of board 
PUSH ($a1)
PUSH ($a2)
jal get_board_color
POP ($a2)
POP ($a1)
bne $v1, $t0, find_and_grab_end    # end the loop if curr color != color of the first ball grabbed
li $a3, 0   # set to empty (grabbed)
PUSH ($a1)
PUSH ($a2)
jal set_board_color
POP ($a2)
POP ($a1)
la $t1, carried_count
lb $t2, carried_count
addiu $t2, $t2, 1   # increment number of carried balls
sb $t2, 0($t1)
addi $a1, $a1, -1
j grab_loop

find_and_grab_end:
POP ($ra)
jr $ra

# ues: $a1, $a2, $a3, $v1, $t1, $t2
handle_throw:
lb $a2, player_x
PUSH ($a2)
jal find_highest_empty
POP ($a2)
move $a1, $v1
lb $t1, carried_count
la $t2, carried_count
lb $a3, carried_color
j push_balls

# throw balls starting at y in the column x
# $a2: x
# $a1: y (starting cell to draw)
push_balls:
beq $a1, 15, game_over  # when throwing too many balls and it reaches the bottom
beq $t1, 0, push_balls_end  # pushed all balls
PUSH ($a3)
PUSH ($a2)
PUSH ($a1)
jal set_board_color
POP ($a1)
POP ($a2)
POP ($a3)
addi $t1, $t1, -1
sb $t1, 0($t2)  # decrement num of carried balls
addiu $a1, $a1, 1   # move one cell below
j push_balls

push_balls_end:
jal paint_board
jal paint_player
j handle_end

handle_end:
POP ($ra)
jr $ra

########################## Bubble destruction logic #############################
# Uses: $t0-$t5, $a1-$a3
# find match, find connected, destroy, apply gravity, repeat, until no more matches
destroy_bubbles:
PUSH ($ra)

destroy_bubbles_repeat:
jal find_matches
lb $t0, 0($s4)
beq $t0, 0, destroy_bubbles_end     # no matches
lb $t0, 1($s4)  # number of matches
li $t1, 0
j cleanup_loop

# looping through $s4 to apply find-connected algorithm to one bubble in each match
# $t1: the index of current match being handled
# $t2: calculated address of the current match
# $t5: current color index of match
# $t4, $t3: current x, y on the board for one of the bubbles in the current match
cleanup_loop:
beq $t1, $t0, apply_gravity     # all matches have been handled
li $t2, 3   # 3 bytes for each match
mul $t2, $t1, $t2
addu $t2, $t2, $s4  # calculate the address for current match
lb $t5, 2($t2)
lb $t4, 3($t2)
lb $t3, 4($t2)
PUSH ($t0)
PUSH ($t1)
jal clean_up
POP ($t1)
POP ($t0)
addiu $t1, $t1, 1
j cleanup_loop

# find and check adjacent recursively, and set all connected bubbles emtpy on the board
# args: $t5 (color index), $t4 (x-coordinate), $t3 (y-coordinate)
clean_up:
PUSH ($ra)
move $a1, $t3
move $a2, $t4
li $a3, 0
jal set_board_color  # set this cell to empty

check_above:
beq $t3, 0, check_below
addi $a1, $t3, -1
move $a2, $t4
jal get_board_color
bne $v1, $t5, check_below   # compare adjacent color vs current cell color
PUSH ($t3)  # save $t3, $t4 as they will be modified in the recursion
PUSH ($t4)
add $t3, $t3, -1
jal clean_up
POP ($t4)
POP ($t3)

check_below:
beq $t3, 15, check_right
addi $a1, $t3, 1
move $a2, $t4
jal get_board_color
bne $v1, $t5, check_right   # compare adjacent color vs current cell color
PUSH ($t3)  # save $t3, $t4 as they will be modified in the recursion
PUSH ($t4)
add $t3, $t3, 1
jal clean_up
POP ($t4)
POP ($t3)

check_right:
beq $t4, 7, check_left
move $a1, $t3
addi $a2, $t4, 1
jal get_board_color
bne $v1, $t5, check_left   # compare adjacent color vs current cell color
PUSH ($t3)  # save $t3, $t4 as they will be modified in the recursion
PUSH ($t4)
add $t4, $t4, 1
jal clean_up
POP ($t4)
POP ($t3)

check_left:
beq $t4, 0, cleanup_done
move $a1, $t3
addi $a2, $t4, -1
jal get_board_color
bne $v1, $t5, cleanup_done   # compare adjacent color vs current cell color
PUSH ($t3)  # save $t3, $t4 as they will be modified in the recursion
PUSH ($t4)
add $t4, $t4, -1
jal clean_up
POP ($t4)
POP ($t3)

cleanup_done:
POP ($ra)
jr $ra

# find matches in every column and save in match ($s4)
# $t0: current column index
# $t4: number of matches found so far (incremented by find_match if there's a match)
find_matches:
PUSH ($ra)
li $t0, 0
li $t4, 0
sb $t4, 0($s4)  # initialize with no match indicator

find_matches_loop:
beq $t0, 8, find_matches_end    # checked every column
move $a2, $t0
jal find_match
addiu $t0, $t0, 1
j find_matches_loop

find_matches_end:
beq $t4, 0, matches_end
sb $t4, 1($s4)  # save number of matches
li $t4, 1
sb $t4, 0($s4)  # indicate there are matches

matches_end:
POP ($ra)
jr $ra

# apply gravity to the board and update its state
apply_gravity:
# TODO
j destroy_bubbles_repeat   # repeat after gravity is applied

destroy_bubbles_end:
jal paint_board
POP ($ra)
jr $ra

###### utils for destruction logic ######
# find the match (there should be only 1) in a specified column on the board (implemented with two pointers)
# args: $a2: x-coordinate of the column
# uses:
# $a1: lead pointer (y-coordinate in the column)
# $t1: trail pointer (y-coordinate in the column)
# $t2: previous color
# $t3: temporarily store length of segment found and the offsetted address for match
# $a2: arg for get_board_color
# $v1: current color returned by get_board_color
find_match:
PUSH ($ra)
li $a1, 15  # start from bottom
li $t1, 15
PUSH ($a1)
PUSH ($a2)
PUSH ($t1)
jal get_board_color
POP ($t1)
POP ($a2)
POP ($a1)
move $t2, $v1

find_match_loop:
addi $a1, $a1, -1
bltz $a1, check_match   # reaching the top
PUSH ($a1)
PUSH ($a2)
PUSH ($t1)
jal get_board_color
POP ($t1)
POP ($a2)
POP ($a1)
bne $v1, $t2, check_match
j find_match_loop

# check whether the current segment is a valid match
check_match:
beq $t2, 0, find_match_continue     # this segment is all black
sub $t3, $t1, $a1   # length of segment
beq $t3, 1, find_match_continue     # length less than 3
beq $t3, 2, find_match_continue
li $t3, 3   # in memory, each match is 3-byte long
mul $t3, $t3, $t4   # multiply by number of matches so far
addu $t3, $t3, $s4  # calculate final address for this match
sb $t2, 2($t3)  # save color, x, y to memory
sb $t0, 3($t3)
sb $t1, 4($t3)
addiu $t4, $t4, 1   # increment match count
j find_match_end

find_match_continue:
bltz $a1, find_match_end   # reaching the top, no more opportunities for this column
move $t1, $a1   # align the two pointers
move $t2, $v1   # align the colors
j find_match_loop

find_match_end:
POP ($ra)
jr $ra
########################## Game-Specific Utils  #################################
# repaint the player to the screen based on player_x, erasing the old position
# uses: $a1, $a2, $a3, $t1

game_over:
j quit

paint_player:
PUSH ($ra)
jal clear_player_area
lb $a2, player_x
addiu $a2, $a2, BOARD_X    # player_x + BOARD_X = player_x_on_bitmap
# paint head (green)
li $a1, PLAYER_Y
li $a3, 2
PUSH ($a2)
jal paint_pixel
POP ($a2)
# paint body 1 (white)
li $a1, PLAYER_Y
addi $a1, $a1, 1
li $a3, 5
PUSH ($a2)
jal paint_pixel
POP ($a2)
# paint body 2 (white)
li $a1, PLAYER_Y
addi $a1, $a1, 2
li $a3, 5
PUSH ($a2)
jal paint_pixel
POP ($a2)
# paint balls
lb $t1, carried_count
lb $a3, carried_color
li $a1, PLAYER_Y
addi $a1, $a1, 3
bne $t1, 0, paint_carried_balls
j paint_carried_balls_end

paint_carried_balls:
beq $t1, 0, paint_carried_balls_end
beq $a1, 32, paint_carried_balls_end
PUSH ($a1)
PUSH ($a2)
PUSH ($a3)
jal paint_pixel
POP ($a3)
POP ($a2)
POP ($a1)
addi $t1, $t1, -1
addi $a1, $a1, 1
j paint_carried_balls

paint_carried_balls_end:
POP ($ra)
jr $ra

# clear the area below the board
# uses $t2, $t3 as x, y
clear_player_area:
li $t2, BOARD_X   # starting column: 2
j clear_loop

clear_loop:
beq $t2, WALL_RIGHT, clear_done   # end when reached right wall
li $t3, PLAYER_Y
j clear_col

clear_col:
beq $t3, 32, next_col   # end when reaching the bottom of bitmap
move $a1, $t3
move $a2, $t2
li $a3, 0   # paint to black (empty)
PUSH ($ra)
jal paint_pixel
POP ($ra)
addiu $t3, $t3, 1
j clear_col

next_col:
addiu $t2, $t2, 1
j clear_loop

clear_done:
jr $ra

# find, on the board, the highest cell in col $a1 that's empty
# args: $a2: player_x value 
# uses: $a1: y value
# uses: $v1
# returns: $v1: the highest y value
find_highest_empty:
PUSH ($ra)
li $a1, 15
PUSH ($a1)
jal get_board_color
POP ($a1)
bne $v1, 0, game_over   # if non-emtpy is already at the bottom, game over
j find_highest_empty_loop 

find_highest_empty_loop:
bltz $a1, find_highest_empty_end
PUSH ($a1)
jal get_board_color
POP ($a1)
bne $v1, 0, find_highest_empty_end
addi $a1, $a1, -1
j find_highest_empty_loop

find_highest_empty_end:
add $v1, $a1, 1
POP ($ra)
jr $ra

advance_rows:
PUSH($ra)
li $t0, 127   # load last board index
ADVANCE_LOOP:
# while i >= 8 (first board index)
beq $t0, 7, ADVANCE_LOOP_END
# compute source address ($s1 + index - BOARD_COLS)
addi $t1, $s1, -BOARD_COLS
add $t1, $t1, $t0
# load from source and store at $s1 + index
lb $t2, 0($t1)
sb $t2, BOARD_COLS($t1)
# decrement index
addi $t0, $t0, -1
j ADVANCE_LOOP
ADVANCE_LOOP_END:
# restore index to 0
li $t0, 0
REFILL_LOOP:
beq $t0, BOARD_COLS, REFILL_LOOP_END
# get & save random color
jal rand
move $a0, $v1
move $a1, $t0
jal save_color
#increment index
addi $t0, $t0, 1
j REFILL_LOOP
REFILL_LOOP_END:
# repaint the board
jal paint_board
# Game over check, loop over last 8 indices.
# if color at that pixel is not empty -> game over.
# reset index
li $t0, 120
GAME_OVER_LOOP:
beq $t0, 128, GAME_OVER_LOOP_END
# load current board pixel
addu $t1, $s1, $t0
lb $t2, 0($t1)
bne $t2, 0, game_over
# increment index
addi $t0, $t0, 1
j GAME_OVER_LOOP
GAME_OVER_LOOP_END:
POP($ra)
jr $ra

########################## General Util Functions ###############################
# randomly select one of RGBY color index (1-4)
# returns: $v1
# uses: $v0, $a0, $a1
rand:
li $v0, 42
li $a0, 0
li $a1, 4
syscall
addi $v1, $a0, 1
jr $ra

# args: $a1: index
# returns: $v1: value
color_index_to_value:
sll $a1, $a1, 2  # calculate offset for color map
addu $a1, $a1, $s0  # calculate address in color map
lw $v1, 0($a1)     # calculate color value
jr $ra

# update the board (does not print) given x, y coordinate and color
# Args:
# $a1: y-coordinate ($a1 gets MODIFIED!!)
# $a2: x-coordinate
# $a3: color index
# uses: $t1
set_board_color: 
sll $a1, $a1, 3
addu $a1, $a1, $a2  # 8 * y + x
addu $a1, $s1, $a1  # board address + offset
sb $a3, 0($a1)
jr $ra

# get the board's color index at x, y
# Args:
# $a1: y-coordinate ($a1 gets MODIFIED!!)
# $a2: x-coordinate
# Returns
# $v1: color index
get_board_color:
sll $a1, $a1, 3
addu $a1, $a1, $a2  # 8 * y + x
addu $a1, $s1, $a1  # board address + offset
lb $v1, 0($a1)
jr $ra

# save color to the board (does not print) given the (flat) index of the board
# Args
# $a0: color index, $a1: board index
save_color:
addu $a1, $a1, $s1  # calculate address for board byte
sb $a0, 0($a1)
jr $ra

# paint pixel on the bitmap
# args: 
# $a1: y-coordinate
# $a2: x-coordinate
# $a3: color index
# uses: $t6: temporary mul factor
paint_pixel:
PUSH ($a1)
move $a1, $a3
PUSH ($ra)
jal color_index_to_value    # takes in $a1, the color index, and outputs $v1, the value
POP ($ra)
POP ($a1)
move $a3, $v1
li $t6, 32
mul  $a1, $a1, $t6   # row * 32 (since 32 pixels per row)
addu $a1, $a1, $a2
li $t6, 4
mul $a1, $a1, $t6  # final offset = (row * 32 + col) * 4
addu $a1, $a1, $s2  # address of bitmap display (top left) + final offset = final address
sw $a3, 0($a1)  # paint the pixel
jr $ra


# print a horizontal line of a given length
# args:
# $a1: y-coordinate
# $a2: x-coordinate
# $a3: colour index
# $a0: length [units]
# uses: $a0 (ends at 0), $a2 (ends at $a2 + $a0), $v1 & $t6 from paint_pixel
paint_hline:
PUSH($ra)
# while remaining length > 0
HLOOP: beq $a0, $zero, HLOOP_END
PUSH($a1)
PUSH($a3)
jal paint_pixel
POP($a3)
POP($a1)
# advance along x 
addi $a2, $a2, 1
# decrement remaining length
addi $a0, $a0, -1
j HLOOP
HLOOP_END:
POP($ra)
jr $ra

# print a vertical line of a given length
# args:
# $a1: y-coordinate
# $a2: x-coordinate
# $a3: colour index
# $a0: length [units]
# uses: $a0 (ends at 0), $a1 (ends at $a1 + $a0), $v1 & $t6 from paint_pixel
paint_vline:
PUSH($ra)
# while remaining length > 0
VLOOP: beq $a0, $zero, VLOOP_END
PUSH($a1)
PUSH($a3)
jal paint_pixel
POP($a3)
POP($a1)
# advance along y
addi $a1, $a1, 1
# decrement remaining length
addi $a0, $a0, -1
j VLOOP
VLOOP_END:
POP($ra)
jr $ra

paint_walls:
# top wall, length 9
li $a2, WALL_LEFT
li $a1, WALL_TOP
li $a3, WALL_COLOR
li $a0, 9
PUSH($ra)
jal paint_hline
POP($ra)
# bottom wall, also length 9
li $a2, WALL_LEFT
li $a1, WALL_BOTTOM
li $a3, WALL_COLOR
li $a0, 9
PUSH($ra)
jal paint_hline
POP($ra)
# left wall, length 18
li $a2, WALL_LEFT
li $a1, WALL_TOP
li $a3, WALL_COLOR
li $a0, 18
PUSH($ra)
jal paint_vline
POP($ra)
# right wall, length 18
li $a2, WALL_RIGHT
li $a1, WALL_TOP
li $a3, WALL_COLOR
li $a0, 18
PUSH($ra)
jal paint_vline
POP($ra)
jr $ra

# paint a given letter on the screen (P, T, or S)
# color is already defined in the bitmap of each letter.
#args:
# $a0: letter address 
# $a1: y-coordinate of top row
# $a2: x-coordinate of leftmost column
#uses:
# $a0 (ends at $a0 + 15)
# $a1 (ends at $a1 + 5)
# $a3 (overwritten)
# $t8, $t9 (row / col counters)
# $v1 & $t6 from paint_pixel
paint_letter:
PUSH($ra)
#init row counter
li $t8, 0
# init col counter
li $t9, 0
# iterate through rows
ROW_LOOP: beq $t8, 5, ROW_LOOP_END
# reset col counter to 0
li $t9, 0
# iterate through cols (nested)
COL_LOOP: beq $t9, 3, COL_LOOP_END
# load color from pointer
lbu $a3, 0($a0)
# paint pixel
PUSH($a1)
jal paint_pixel
POP($a1)
#increment x
addi $a2, $a2, 1
#increment col counter
addi $t9, $t9, 1
# advance pointer
addi $a0, $a0, 1
j COL_LOOP
COL_LOOP_END:
# reset x to x - 3
addi $a2, $a2, -3
# increment y
addi $a1, $a1, 1
# increment row counter
addi $t8, $t8, 1
j ROW_LOOP
ROW_LOOP_END:
POP($ra)
jr $ra

# print the board on display based on the stored board color values
# uses:
# $t0: board index
paint_board:
PUSH ($ra)
add $t0, $zero, $zero
j paint_board_loop

paint_board_loop:
beq $t0, 128, paint_board_end    # finished painting all 128 pixels
move $a0, $t0
jal paint_cell
addi $t0, $t0, 1 # update offset
j paint_board_loop

paint_board_end:
POP ($ra)
jr $ra

# args: $a0 - given board index (flat index) to print
# uses: $a1-$a3, $v1, $t4-$t7
paint_cell:
addu $t7, $a0, $s1  # board adddress
lb $a3, 0($t7)  # get color index from board
# calculate display address
srl $t4, $a0, 3     # row on the board
andi $t5, $a0, 7    # column on the board
addi $a1, $t4, BOARD_Y    # y-coordinate on the bitmap
addi $a2, $t5, BOARD_X    # x-coordinate on the bitmap
# paint pixel
PUSH ($ra)
jal paint_pixel
POP ($ra)
jr $ra
