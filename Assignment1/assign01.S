#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu    cortex-m0plus
.thumb
.global main_asm
.align  4

.equ    DFLT_STATE_STRT, 1            @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default alarm timeout
.equ    SLEEP_TIME, 100               @ Specify the amount of ms that we want to sleep for in the loop

.equ    GPIO_BTN_DN_MSK, 0x00040000   @ Bit-18 for falling-edge event on GP20
.equ    GPIO_BTN_EN_MSK, 0x00400000   @ Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x04000000   @ Bit-26 for falling-edge event on GP22

.equ    GPIO_BTN_DN,  20              @ Specify pin for the "down" button
.equ    GPIO_BTN_EN,  21              @ Specify pin for the "enter" button
.equ    GPIO_BTN_UP,  22              @ Specify pin for the "up" button
.equ    GPIO_LED_PIN, 25              @ Specify pin for the built-in LED
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin

.equ    LED_VAL_ON,    1              @ Specify value that turns the LED "on"
.equ    LED_VAL_OFF,   0              @ Specify value that turns the LED "off"

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)

//
// Main entry point into the ASM portion of the code
//
main_asm:
    bl    init_leds                     @Same as previous labs
    bl    init_btns                     @Use asm_gpio_set_irq C function to setup falling-edge interrutps
    bl    install_alrm_isr              @Initilise the ALARM interrupt
    bl    install_gpio_isr              @Initilise the GPIO Interrupt interrupt
    ldr     r4, =DFLT_ALARM_TIME        @ Load default time for Alarm 
    ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET) @ Enable the alarm by writing 1 to the register 
    movs    r1, #1
    str     r1, [r2]
loop:
    bl    set_alarm           // Set a new alarm
    wfi                       // Wait here until any interrupt fires
    b     loop                // Always branch back to loop


init_leds:
    push    {lr} 
    movs    r0, #GPIO_LED_PIN           @ This value is the GPIO LED pin on the PI PICO board
    bl      asm_gpio_init               @ Call the subroutine to initialise the GPIO pin specified by r0
    movs    r0, #GPIO_LED_PIN           @ This value is the GPIO LED pin on the PI PICO board
    movs    r1, #GPIO_DIR_OUT           @ We want this GPIO pin to be setup as an output pin
    bl      asm_gpio_set_dir            @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
    pop     {pc} 

init_btns:
    push    {lr} 
    @GPIO20
    movs    r0, #GPIO_BTN_DN            @ Initialise the Down Button (GPIO 20)               
    bl      asm_gpio_init               @
    movs    r0, #GPIO_BTN_DN            @ Set buttton as an input               
    movs    r1, GPIO_DIR_IN             @
    bl      asm_gpio_set_dir            @
    movs    r0, #GPIO_BTN_DN            @ Enable the interupt for the pin               
    bl      asm_gpio_set_irq            @    
    @GPIO21
    movs    r0, #GPIO_BTN_EN            @ Initialise the Enter Button (GPIO 21)                
    bl      asm_gpio_init               @
    movs    r0, #GPIO_BTN_EN            @ Set buttton as an input              
    movs    r1, GPIO_DIR_IN             @ 
    bl      asm_gpio_set_dir            @
    movs    r0, #GPIO_BTN_EN            @ Enable the interupt for the pin 
    bl      asm_gpio_set_irq            @     
    @GPIO22
    movs    r0, #GPIO_BTN_UP            @ Initialise the Enter Button (GPIO 21)
    bl      asm_gpio_init               @
    movs    r0, #GPIO_BTN_UP            @ Set buttton as an input             
    movs    r1, GPIO_DIR_IN             @
    bl      asm_gpio_set_dir            @
    movs    r0, #GPIO_BTN_UP            @ Enable the interupt for the pin             
    bl      asm_gpio_set_irq            @    
    pop     {pc} 
//
// Enable alarm timer interrupts and set an alarm
//
set_alarm:
    ldr     r2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)     @Get the current timer count from (TIMER_BASE + TIMER_TIMELR_OFFSET) register
    ldr     r1, [r2]                                    @
    movs    r0, r4                                      @ Load r4 which is the current time delay based on the button interrupts 
    add     r1, r0                                      @ Add the time delay you want to wait for to the current timer count
    ldr     r2, =(TIMER_BASE + TIMER_ALARM0_OFFSET)     @ Push the updated value to (TIMER_BASE + TIMER_ALARM0_OFFSET)
    str     r1, [r2]                                    @
    bx      lr                                          @Exit subroutine

//
// Sets up the alrm_isr in the RAM vector table and enables the correct interrupt
//
install_alrm_isr:

    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    @ Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    movs    r1, #1                                  @
    ldr     r1, [r2]                                @
    movs    r2, #ALRM_ISR_OFFSET                    @ Load the offset value for ALARM0
    add     r2, r1                                  @
    ldr     r0, =alrm_isr                           @ Store the address of the alrm_isr handler to the correct offset for ALARM0 in the vector table
    str     r0, [r2]                                @

    movs    r0, #1                                      @
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)   @ Disable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    str     r0, [r2]                                    @
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   @ Enable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    str     r0, [r2]                                    @
    bx      lr                                          @ Exit subroutine

.thumb_func
alrm_isr:
    push    {lr}                        @ Store the link register to the stack as we will call nested subroutines
    movs    r0, #GPIO_LED_PIN           @ Set the LED GPIO pin number to r0 for use by asm_gpio_get
    bl      asm_gpio_get                @ Get current the value of the LED GPIO pin (returns to r0)
    cmp     r0, #LED_VAL_OFF            @ Check if the LED GPIO pin value is "off"
    beq     led_set_on                  @ If it is "off" then then jump code to to turn it on
led_set_off:
    movs    r1, #LED_VAL_OFF            @ The LED is currently "on" so we want to turn it "off"
    b       led_set_state               @ Jump to portion of code where we set the state of the LED
led_set_on:
    movs    r1, #LED_VAL_ON             @ The LED is currently "off" so we want to turn it "on"
led_set_state:
    movs    r0, #GPIO_LED_PIN           @ Set the LED GPIO pin number to r0 for use by asm_gpio_put
    bl      asm_gpio_put                @ Update the the value of the LED GPIO pin (based on value in r1)
    movs    r0, #1
    ldr     r2, =(TIMER_BASE + TIMER_INTR_OFFSET) 
    str     r0, [r2]
    pop     {pc}                        @ Pop the link register from the stack to the program counter

//
// Sets up the gpio_isr in the RAM vector table and enables the correct interrupt
//
install_gpio_isr:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)           @ Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register                                      
    ldr     r1, [r2]                                       @     
    movs    r2, #GPIO_ISR_OFFSET                           @ Load GPIO IRQ offset which is entry 13 in table                                     
    add     r2, r1                                         @                     
    ldr     r0, =gpio_isr                                  @ Store the address of the gpio_isr handler to the correct offset for GPIO in the vector table                
    str     r0, [r2]                                       @     

    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)      @ Disable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)                                                            
    ldr     r1, =0x2000                                    @                             
    str     r1, [r2]                                       @                             

    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)      @ Enable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)                                                            
    ldr     r1, =0x2000                                    @                             
    str     r1, [r2]                                       @                             
    bx      lr                                             @ Exit subroutine                    
//
// Service the pending interrupt from the GPIO
//
.thumb_func
gpio_isr:
    push {lr}
    ldr  r2, =(TIMER_BASE + TIMER_INTE_OFFSET)                 @ Get state of LED for comparison
    ldr  r3 ,[r2]                                              @ 
    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)    @ Read the interrupt status event from the (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) register
    Ldr  r1, [r2]   	                                       @ 
    ldr  r0 ,=0x2000                                           @ 
    str  r0,[r2]                                               @ 

    ldr  r2,=GPIO_BTN_UP_MSK                                   @ Load UP button mask 
    cmp  r2, r1                                                @ Compare to status event to check button 
    beq  up                                                    @ Branch  

    ldr  r2,=GPIO_BTN_DN_MSK                                   @ Load DOWN button mask
    cmp  r2, r1                                                @ Compare to status event to check button
    beq  down                                                  @ Branch

    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)          @ Load interrupt status from (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)
    ldr  r1,=GPIO_BTN_EN_MSK                                   @ Load button mask 
    str  r1,[r2]                                               @ Reset button status 
    ldr  r2,=DFLT_STATE_STOP                                   @ Load default stop state
    cmp  r3, r2                                                @ 
    bne  disable                                               @ If the are =/= disable alarm interrupt

    ldr  r2, =(TIMER_BASE + TIMER_INTE_OFFSET)                 @ IF they are equal, enable alarm interrupt 
    movs r1,#1                                                 @ 
    str  r1, [r2]                                              @ 
    bl   done                                                  @ Done and exit 
disable:
    ldr  r2, =(TIMER_BASE + TIMER_INTE_OFFSET)                 @ Disable alarm interrupt 
    movs r1,#0                                                 @ 
    str  r1, [r2]                                              @ 
    bl   done                                                  @ Done and exit 
down:
    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)          @ Load interrupt status from (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)
    ldr  r1,=GPIO_BTN_DN_MSK                                   @ Load button mask
    str  r1,[r2]                                               @ Reset button interupt status
    lsrs r4, r4,#1                                             @ half the alarm time by shifting right by 1 bit 
    bl   done 
up:
    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)          @ Load interrupt status from (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)
    ldr  r1,=GPIO_BTN_UP_MSK                                   @ Load button mask
    str  r1,[r2]                                               @ Reset button interrupt status
    lsls r4, r4,#1                                             @ Double alarm time by shifting to left by 1 bit 
    bl   done  
done:  
    pop {pc} 

.align 4
msg:    .asciz "Hello World!\n"

.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME
