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
    
COLOR_MAP:
    .word 0x00ffffff    # White
    .word 0x00ff0000    # Red
    .word 0x0000ff00    # Green
    .word 0x000000ff    # Blue
    .word 0x00ffff00    # Yellow
    

##############################################################################
# Mutable Data
##############################################################################

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
    # 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen

	# 4. Sleep
	li $v0, 32
	li $a0, 16

    # 5. Go back to Step 1
    j game_loop
    
quit:
li $v0, 10
syscall
    
init:
lw $s0, ADDR_DSPL
move $t0, $s0
jal draw
j game_loop

draw:
jal rand

sw $t1, 0($t0)
addi $t0, $t0, 4

jr

rand:
$v0 42
$a0 0
$a1 4
syscall
jr