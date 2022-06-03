#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu    cortex-m0plus
.thumb
.global main_asm
.global input
.global grabArray
.align  4

.equ    DFLT_STATE_STRT, 1            @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 3000000      @ Specify the default alarm timeout
.equ    SLEEP_TIME, 100               @ Specify the amount of ms that we want to sleep for in the loop

.equ    GPIO21_EDGE_LOW, 0x00400000   @ Bit-22 for falling-edge event on GP21
.equ    GPIO21_EDGE_HIGH, 0x00800000   @ Bit-23 for rising-edge event on GP21
.equ    DASH_TIME, 250000
.equ    SPACE, 1000000

.equ    GPIO_BTN_EN,  21              @ Specify pin for the "enter" button
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin
.equ    GPIO_LED_PIN, 25              @ Specify pin for the built-in LED

.equ    LED_VAL_ON,    1              @ Specify value that turns the LED "on"
.equ    LED_VAL_OFF,   0              @ Specify value that turns the LED "off"

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)

//
// Main entry point into the ASM portion of the code
//
main_asm:
    push  {lr}
    bl    init_leds                                 @Same as previous labs
    bl    init_btns                                 @Use asm_gpio_set_irq C function to setup falling-edge interrutps
    bl    install_alrm_isr                          @Initilise the ALARM interrupt
    bl    install_gpio_isr                          @Initilise the GPIO Interrupt interrupt
    ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)   @ Enable the alarm by writing 1 to the register 
    movs    r1, #0
    str     r1, [r2]
    ldr r4, =0                                      @Break loop flag 
    pop   {pc}
input:
    //bl    set_alarm           // Set a new alarm
    push {lr}
    //------
    ldr r4, =0                           
    @ bl set_alarm
    @ ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)   @ Enable the alarm by writing 1 to the register 
    @ movs    r1, #0
    @ str     r1, [r2]
    //--------

loop:
    wfi                       // Wait here until any interrupt fires
    cmp r4, #1
    beq out
    b     loop                // Always branch back to loop
out:
    pop {pc}

init_btns:
    push    {lr} 

    @GPIO21
    movs    r0, #GPIO_BTN_EN            @ Initialise the Enter Button (GPIO 21)                
    bl      asm_gpio_init               @
    movs    r0, #GPIO_BTN_EN            @ Set buttton as an input              
    movs    r1, GPIO_DIR_IN             @ 
    bl      asm_gpio_set_dir            @
    movs    r0, #GPIO_BTN_EN            @ Enable the interupt for the pin 
    bl      asm_gpio_set_irq            @ Sets up IRQ for both rising and falling edge events 

    pop {pc}

init_leds:
    push    {lr} 
    movs    r0, #GPIO_LED_PIN           @ This value is the GPIO LED pin on the PI PICO board
    bl      asm_gpio_init               @ Call the subroutine to initialise the GPIO pin specified by r0
    movs    r0, #GPIO_LED_PIN           @ This value is the GPIO LED pin on the PI PICO board
    movs    r1, #GPIO_DIR_OUT           @ We want this GPIO pin to be setup as an output pin
    bl      asm_gpio_set_dir            @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
    pop     {pc} 

//
// Enable alarm timer interrupts and set an alarm
//
set_alarm:

    ldr     r2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)     @Get the current timer count from (TIMER_BASE + TIMER_TIMELR_OFFSET) register
    ldr     r1, [r2]                                    @
    ldr     r0, =DFLT_ALARM_TIME
    add     r1, r0                                      @ Add the time delay you want to wait for to the current timer count
    ldr     r2, =(TIMER_BASE + TIMER_ALARM0_OFFSET)     @ Push the updated value to (TIMER_BASE + TIMER_ALARM0_OFFSET)
    str     r1, [r2]                                    @
    ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET) @ Enable the alarm by writing 1 to the register 
    movs    r1, #1
    str     r1, [r2]
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

    movs    r0, #1                                  @clear interupt
    ldr     r2, =(TIMER_BASE + TIMER_INTR_OFFSET) 
    str     r0, [r2]

    ldr r0, =alarmmsg
    bl printf
    //bl set_alarm

    bl full
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

    bl dogUpdate

    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)      @ Read the interrupt status event from the (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) register
    ldr     r1, [r2]   	                                            @ 

    ldr     r0, =GPIO21_EDGE_LOW                                    @ Load low edge mask for button mask 
    cmp     r0, r1                                                  @ Compare
    beq rising
    
    ldr     r0, =GPIO21_EDGE_HIGH                                   @ Load high edge mask for button mask
    cmp     r0, r1                                                  @ Compare
    beq falling

    ldr r0, =skipmsg
    bl printf

rising: 
    @ ldr     r0, =risemsg
    @ bl printf
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)           @ Load interrupt status from (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)
    ldr     r1,=GPIO21_EDGE_LOW                                    @ Load button mask
    str     r1,[r2]                                                @ Reset button interrupt status
    ldr     r2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)             @Get the current timer count from (TIMER_BASE + TIMER_TIMELR_OFFSET) register
    ldr     r6, [r2]

    b done
falling:
    @ ldr     r0, =fallmsg
    @ bl printf
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)           @ Load interrupt status from (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)
    ldr     r1,=GPIO21_EDGE_HIGH                                   @ Load button mask
    str     r1,[r2]                                                @ Reset button interrupt status

    ldr     r2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)             @Get the current timer count from (TIMER_BASE + TIMER_TIMELR_OFFSET) register
    ldr     r7, [r2]

    subs    r0, r7, r6                                          @ Get time diff 
    ldr     r1, =DASH_TIME                                      @ Load dash time
    cmp     r0, r1                                              @ 
    bhs dash 

dot: 

    ldr     r0, =dotmsg
    bl printf
    ldr     r0, =array          @ Load memory address of array 
    ldr     r1, =iter           @ Load memory address of iterable
    ldr     r2 ,[r1]            @ Load value of iterable
    adds    r0, r2              @ add the iterable to the value of th earray to get to teh current index

    ldr     r1, =0x2E           @ Write DOT '.' value  
    str     r1, [r0]            @ Store dot value in current array index 

    bl iterate

dash: 
    
    ldr     r0, =dashmsg
    bl printf
    ldr     r0, =array          @ Load address of array 
    ldr     r1, =iter           @ Load address of iter 
    ldr     r2 ,[r1]            @ Read value of iter 
    adds    r0, r2              @ Go to current index of array 
    ldr     r1, =0x2D           @ Write DASH '-' to array 
    str     r1, [r0]            @ Store
    bl iterate                  @ Branch to iterate 

iterate:
    ldr     r1, =iter           @ load iter
    ldr     r2 ,[r1]            @ Get value of iter 
    adds    r2, #4              @ Add 4 to iter for size of bytes 
    str     r2, [r1]            @ Store value back to iter 
    bl done

done:  

    bl set_alarm
    pop {pc} 

full:

    ldr     r0, =array          @ Load array address
    ldr     r1, =iter           @ Load iter variable address 
    ldr     r2 ,[r1]            @ Get value of current iter
    adds    r0, r2              @ Go to index[iter] of the array 
    ldr     r1, =0x0            @ Load 0x0 ('\0') in char form
    str     r1, [r0]            @ Store to current index  ----changed from r2 to r0
    ldr     r0, =array          @ Load index 0 of array 
    @ bl buffer_test              @ Call function to parse array to string (Will move in future)
    ldr     r1, =iter           @ Load Iter address
    ldr     r0, =0x0            @ Load 0 to reset iter variable
    str     r0, [r1]            @

    //bl    install_alrm_isr                          @Initilise the ALARM interrupt
    ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)   @ Disable the alarm by writing 0 to the register 
    movs    r1, #0                                  @
    str     r1, [r2]                                @
    //--------------
    @ ldr  r0 ,=0x2000                                           @ 
    @ str  r0,[r2]   
    //bl    install_alrm_isr                          @Initilise the ALARM interrupt



    ldr r4, =1                                  @Set flag to break in the wait for loop 

    pop {pc}

grabArray:
    push {lr}
    ldr r0, =array              @ Gets the address of the first index of array  
    pop {pc}

.align 4
msg:    .asciz "Hello World!\n"
risemsg:    .asciz "Hello rise!\n"
fallmsg:    .asciz "Hello fall!\n"
skipmsg:    .asciz "I skipped both!\n"
alarmmsg: .asciz "The alarm has sounded!\n"
dotmsg: .asciz "DOT!\n"
dashmsg: .asciz "DASH!\n"
//alarmmsg: .asciz "The alarm has sounded!\n"

.data
array:      .skip 24 //makes an array of 6 elements 
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME
iter: .word     0
