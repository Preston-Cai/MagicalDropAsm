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
    
COLOR_MAP:  # color index: 1 is red, 2 is green, 5 is white, ...
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
board:  # containing colors (each byte contains the color index)
    .space 128  # 8 columns, 16 rows
mark:   # marked to be destroyed
    .space 128
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
la $s1 board    # saved constant: board's memory address
lw $s2, ADDRESS_DSPL_BOARD_START    # saved constant: starting address of the board on the bitmap
jal draw_init
j game_loop

# $t0: loop index; $t1: current address
draw_init:
addi $sp, $sp, -4   # store in call stack
sw $ra, 0($sp)
add $t0, $zero, $zero
j draw_init_loop

# $t0: current board index
draw_init_loop:
beq $t0, 40, draw_init_end   # fill first 5 rows * 8 per row
jal rand
jal save_color      # argument is $a0 (color index), $t0 (board index)
addi $t0, $t0, 1    # next byte on the board
j draw_init_loop

draw_init_end:
jal paint_board
lw $ra, 0($sp)      # pop the stack
add $sp, $sp, 4
jr $ra

# $a0: color index
save_color:
addu $t1, $t0, $s1  # calculate address for board byte
sb $a0, 0($t1)
jr $ra

rand:
li $v0, 42
li $a0, 0
li $a1, 4
syscall
addi $a0, $a0, 1
jr $ra

# $t0: board index
paint_board:
addi $sp, $sp, -4   # store in call stack
sw $ra, 0($sp)
add $t0, $zero, $zero
j paint_board_loop

paint_board_loop:
beq $t0, 128, paint_board_end    # finished painting all 128 pixels
move $a0, $t0
jal paint_cell
addi $t0, $t0, 1 # update offset
j paint_board_loop

paint_board_end:
lw $ra, 0($sp)      # pop the stack
add $sp, $sp, 4
jr $ra

# args: $a0 - given board index to print
# $t2: pixel address to print
# $t1: color index (and updated to color map address)
# $t3: current color value
# $t4: row on the board (later on the display)
# $t5: column on the board (later on the display)
# $t7: current board address
paint_cell:
addu $t7, $a0, $s1  # board adddress
# calculate color value
lb $t1, 0($t7)  # get color index from board
sll $t1, $t1, 2  # calculate offset for color map
addu $t1, $t1, $s0  # calculate address in color map
lw $t3, 0($t1)     # calculate color value
# calculate display address
srl $t4, $a0, 3
andi $t5, $a0, 7
li $t6, 32
mul $t4, $t4, $t6   # row * 32 (since 32 pixels per row)
li $t6, 4
mul $t4, $t4, $t6   # (row * 32) * 4 (each pixel is 4 bytes)
mul $t5, $t5, $t6   # col * 4
addu $t2, $t4, $t5  # final offset = (row * 32 + col) * 4
addu $t2, $t2, $s2  # address of board start + final offset = final address
sw $t3, 0($t2)  # paint the pixel
jr $ra


keyboard_input:
# TODO
jr $ra