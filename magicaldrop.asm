################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Magical Drop.
#
# Student 1: Preston Cai, 1012556440
# Student 2: Name, Student Number (if applicable)
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

ADDRESS_DSPL_BOARD_START:
    .word 0x10008388   # ADDR_DSPL + (32 * 7 + 2) * 4 = 904 = 388_hex (since our board starts at (8, 3))
##############################################################################
# Mutable Data
##############################################################################
board:  # containing colors (a byte per cell, each byte contains the color index)
    .space 128  # 8 columns, 16 rows
score:
    .word 0   # maximum score 2^32
carried_count:
    .byte 0
carried_color:  # color index only needs 1 byte
    .space 1
player_x:
    .byte 3    # position of player on the board (0-7, as there are 8 columns)
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
jal draw_initial_board
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
# uses: $t1, $t2
keyboard_input:
PUSH ($ra)
lw $t1, 0($s3)
beq $t1, 1, handle_input
j handle_end

handle_input:
lw $t1, 4($s3)   # key pressed in ascii
beq $t1, 0x61, handle_left
beq $t1, 0x64, handle_right
beq $t1, 0x73, handle_grab      # key s
beq $t1, 0x77, handle_throw     # key w

handle_left:
la $t1, player_x
lb $t2, player_x
beq $t2, 0, handle_end  # cannot move further left
addi $t2, $t2, -1
sb $t2, 0($t1)
jal paint_player
j handle_end

handle_right:
la $t1, player_x
lb $t2, player_x
beq $t2, 7, handle_end  # cannot move further right
addi $t2, $t2, 1
sb $t2, 0($t1)
jal paint_player
j handle_end

handle_grab:
# TODO
j handle_end

handle_throw:
# TODO
j handle_end

handle_end:
POP ($ra)
jr $ra

########################## Game-Specific Utils  #################################
# repaint the player to the screen based on player_x, erasing the old position
# uses: $a1, $a2, $a3, $t1
paint_player:
PUSH ($ra)
jal clear_player_area
lb $a2, player_x
addiu $a2, $a2, 2    # player_x + 2 = player_x_on_bitmap
# paint head (green)
li $a1, 23
li $a3, 2
PUSH ($a2)
jal paint_pixel
POP ($a2)
# paint body 1 (white)
li $a1, 24
li $a3, 5
PUSH ($a2)
jal paint_pixel
POP ($a2)
# paint body 2 (white)
li $a1, 25
li $a3, 5
PUSH ($a2)
jal paint_pixel
POP ($a2)
# paint balls
lb $t1, carried_count
lb $a3, carried_color
li $a1, 26
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
li $t2, 2   # starting column: 2
j clear_loop

clear_loop:
beq $t2, 10, clear_done   # end when reaching column 10
li $t3, 23  # highest row of player area: 24th row
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


########################## General Util Functions ###############################
# randomly select one of RGBY color index (1-4)
# returns: $v0
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
# $a1: y-coordinate
# $a2: x-coordinate
# $a3: color index
set_board_color: 
srl $a1, $a1, 3
addu $a1, $a1, $a2  # 8 * y + x
addu $a1, $s1, $a1  # board address + offset
sw $a3, 0($a1)

# get the board's color index at x, y
# Args:
# $a1: y-coordinate
# $a2: x-coordinate
# Returns
# $v1: color index
get_board_color:
srl $a1, $a1, 3
addu $a1, $a1, $a2  # 8 * y + x
addu $a1, $s1, $a1  # board address + offset
lb $v1, 0($a1)

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
addi $a1, $t4, 6    # y-coordinate on the bitmap (starting pixel of board (3, 7))
addi $a2, $t5, 2    # x-coordinate on the bitmap
# paint pixel
PUSH ($ra)
jal paint_pixel
POP ($ra)
jr $ra
