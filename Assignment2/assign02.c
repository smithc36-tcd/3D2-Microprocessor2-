// Must declare the main assembly entry point before use.
void main_asm();
void input();
char *grabArray();

#include "assign02.pio.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "pico/stdlib.h"
#include "hardware/pio.h"
#include "hardware/gpio.h"
#include "hardware/watchdog.h"

#define IS_RGBW true  // Will use RGBW format
#define NUM_PIXELS 1  // There is 1 WS2812 device in the chain
#define WS2812_PIN 28 // The GPIO pin that the WS2812 connected to

int level = 1;                    /**< Variable to control the players level, where the default is set to 1*/
int exitGame = 0;                 /**< Controls the GameOver state */
PIO pio = pio0;                   /**< PIO object to control the RGB LED*/
int indexGoal;                    /**< Index of desired Alphanumerica character */
int correctGuesses, totalCorrect; /**< Total correct guesses */
int lives, livesLost;             /**< Lives of the player */

/**
 * @brief Array of morse values mapped from 0-9/A-Z
 *
 */
char *morse[] = {"-----", ".----", "..---", "...--", "....-", ".....",
                 "-....", "--...", "---..", "----.", ".-", "-...", "-.-.", "-..", ".",
                 "..-.", "--.", "....", "..", ".---", "-.-", ".-..", "--", "-.", "---",
                 ".--.", "--.-", ".-.", "...", "-", "..-", "...-", ".--", "-..-", "-.--", "--."};

/**
 * @brief Array of Alphanumeric characters mapped identically to the morse[]m array
 *
 */
char *letters[] = {"0", "1", "2", "3", "4", "5",
                   "6", "7", "8", "9", "A", "B", "C", "D", "E",
                   "F", "G", "H", "I", "J", "K", "L", "M", "N", "O",
                   "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"};

/**
 * @brief Initialise a GPIO pin – see SDK for detail on gpio_init()
 *
 */
void asm_gpio_init(uint pin)
{
    gpio_init(pin);
}

/**
 * @brief Set direction of a GPIO pin – see SDK for detail on gpio_set_dir()
 *
 */
void asm_gpio_set_dir(uint pin, bool out)
{
    gpio_set_dir(pin, out);
}

/**
 * @brief Get the value of a GPIO pin – see SDK for detail on gpio_get()
 *
 */
bool asm_gpio_get(uint pin)
{
    return gpio_get(pin);
}

//
/**
 * @brief Set the value of a GPIO pin – see SDK for detail on gpio_put()
 *
 */
void asm_gpio_put(uint pin, bool value)
{
    gpio_put(pin, value);
}

/**
 * @brief Enable falling-edge interrupt – see SDK for detail on gpio_set_irq_enabled()
 *
 */
void asm_gpio_set_irq(uint pin)
{
    gpio_set_irq_enabled(pin, GPIO_IRQ_EDGE_FALL | GPIO_IRQ_EDGE_RISE, true);
}
void dogUpdate()
{
    watchdog_update();
}

/**
 * @brief Function to return a timestamp
 * @return Returns a timestap
 */
int get_time()
{
    return time_us_64();
}

/**
 * @brief Function to update the watchdogg timer
 *          which is to be called when any input is detected
 *
 */
void dogUpdate()
{
    watchdog_update();
}

/**
 * @brief A simple print function to display a welcome graphic
 *
 */
void gameGraphic()
{
    printf("\033[1;35m");
    printf(" ====================================\n");
    printf(" Assignment 2\t Done by Group 21\n");
    printf(" ====================================\n");
    printf("#      #####      #     ####    #   #\n");
    printf("#      #         # #    #   #   ##  #\n");
    printf("#      ####     #   #   ####    # # #\n");
    printf("#      #       #######  # #     #  ##\n");
    printf("#####  #####  #       # #   #   #   #\n");
    printf("\n");
    printf("#     #   ###   ####     ###   ##### \n");
    printf("##   ##  #   #  #   #   #      #     \n");
    printf("#  #  #  #   #  ####     ###   ####  \n");
    printf("#     #  #   #  # #         #  #     \n");
    printf("#     #   ###   #   #    ###   ##### \n");
    printf("=====================================\n");
    printf(" \n # INSTRUCTIONS TO PLAY #\n");
    printf(" -> A alphanumeric character will be printed to the screen\n");
    printf(" -> Your task is to enter the correct morse code equivalent\n");
    printf("    Using the GP21 button\n");
    printf(" -> For morse dot -> Press GP21 button for short duration.\n");
    printf(" -> For morse dash -> Press GP21 button for long duration.\n");
    printf(" -> If your answer is correct, you will receive a life (MAX 3 lives)\n");
    printf(" -> If your answer is incorrect, you will lose a life\n");
    printf(" -> If all of your lifes are over, the GAME'S OVER\n");
    printf(" -> If you get 5 correct sequences in a row, you proceed to the next level.\n");
    printf("\033[0;39m");
}

/**
 * @brief A simple print function to display a gameover graphic
 *
 */
void GameOverGraphic()
{
    printf("███▀▀▀██┼███▀▀▀███┼███▀█▄█▀███┼██▀▀▀\n");
    printf("██┼┼┼┼██┼██┼┼┼┼┼██┼██┼┼┼█┼┼┼██┼██┼┼┼\n");
    printf("██┼┼┼▄▄▄┼██▄▄▄▄▄██┼██┼┼┼▀┼┼┼██┼██▀▀▀\n");
    printf("██┼┼┼┼██┼██┼┼┼┼┼██┼██┼┼┼┼┼┼┼██┼██┼┼┼\n");
    printf("███▄▄▄██┼██┼┼┼┼┼██┼██┼┼┼┼┼┼┼██┼██▄▄▄\n");
    printf("┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼┼\n");
    printf("███▀▀▀███┼▀███┼┼██▀┼██▀▀▀┼██▀▀▀▀██▄┼\n");
    printf("██┼┼┼┼┼██┼┼┼██┼┼██┼┼██┼┼┼┼██┼┼┼┼┼██┼\n");
    printf("██┼┼┼┼┼██┼┼┼██┼┼██┼┼██▀▀▀┼██▄▄▄▄▄▀▀┼\n");
    printf("██┼┼┼┼┼██┼┼┼██┼┼█▀┼┼██┼┼┼┼██┼┼┼┼┼██┼\n");
    printf("███▄▄▄███┼┼┼─▀█▀┼┼─┼██▄▄▄┼██┼┼┼┼┼██▄\n");
}

/**
 * @brief A function to print suitable statistics of a players
 *          preformance after the has finished
 *
 */
void statistics()
{
    int percentageCorrect = ((totalCorrect * 100) / (totalCorrect + livesLost));
    printf("***************************\n");
    printf("Statistics: ");
    printf("Total correct guesses: %d \n", totalCorrect);
    printf("Total lives lost: %d \n", livesLost);
    printf("Percent Correct: %d %% \n", percentageCorrect);
    printf("***************************\n");
}

/**
 * @brief Wrapper function used to call the underlying PIO
 *        function that pushes the 32-bit RGB colour value
 *        out to the LED serially using the PIO0 block. The
 *        function does not return until all of the data has
 *        been written out.
 *
 * @param pixel_grb The 32-bit colour value generated by urgb_u32()
 */
static inline void put_pixel(uint32_t pixel_grb)
{
    pio_sm_put_blocking(pio0, 0, pixel_grb << 8u);
}

/**
 * @brief Function to generate an unsigned 32-bit composit GRB
 *        value by combining the individual 8-bit paramaters for
 *        red, green and blue together in the right order.
 *
 * @param r     The 8-bit intensity value for the red component
 * @param g     The 8-bit intensity value for the green component
 * @param b     The 8-bit intensity value for the blue component
 * @return uint32_t Returns the resulting composit 32-bit RGB value
 */
static inline uint32_t urgb_u32(uint8_t r, uint8_t g, uint8_t b)
{
    return ((uint32_t)(r) << 8) |
           ((uint32_t)(g) << 16) |
           (uint32_t)(b);
}

/**
 * @brief An input function to choose the levels of difficulty
 *
 */
void levelInput()
{
    printf("Please enter the level you would like to attempt:\n");
    printf("Enter: '.----' for level 1\n");
    printf("Enter: '..---' for level 2\n");
    input();
    watchdog_update();

    char *levelInput = grabArray();
    char morsereturn[6];
    for (int i = 0; i < 6; i++)
    {
        morsereturn[i] = *(levelInput + (i * 4));
    }
    char *string = morsereturn;

    if (strcmp(string, morse[1]) == 0)
    {
        level = 1;
    }
    if (strcmp(string, morse[2]) == 0)
    {
        level = 2;
    }
}

/**
 * @brief A function which changes the colour of the LED
 *          based on the  number of lives the player has left
 *
 */
void livesColourChange()
{
    switch (lives)
    {
    case 3:
        // Put green
        printf("\033[1;32m");
        put_pixel(urgb_u32(0x00, 0x7F, 0x00));
        break;
    case 2:
        // Put orange
        printf("\033[0;33m");
        put_pixel(urgb_u32(0x2F, 0xC, 0x00));
        break;
    case 1:
        // put yellow
        printf("\033[1;33m");
        put_pixel(urgb_u32(0x7F, 0x7F, 0x00));
        break;
    case 0:
        // put red
        printf("\033[1;31m");
        put_pixel(urgb_u32(0x7F, 0x00, 0x00));
    default:
        // put green
        put_pixel(urgb_u32(0x00, 0x7F, 0x00));
        break;
    }
}

/**
 * @brief A function which searches through the morse code
 *          array and compares the strings to find the index
 *          of the given string
 *
 * @param test string to be tested against
 * @return index of the given morse code input or -1 given an invalid code
 */
int morseSearch(char *test)
{
    for (int i = 0; i < 35; i++)
    {
        if (!strcmp(test, morse[i]))
        {
            return i;
        }
    }
    return -1;
}

/**
 * @brief function to convery the ASM array to a char * and return whether
 *          the input was correct or incorrect. Prints the alphanumeric
 *          equivelent of the input more
 *
 * @param input first character of the array input from the arm code
 * @return Returns a boolean based on whether the input was correct or incorrect
 */
int convertArray(char *input)
{
    char morsereturn[6];
    for (int i = 0; i < 6; i++)
    {
        morsereturn[i] = *(input + (i * 4));
    }
    char *string = morsereturn;
    int indexOfInput = morseSearch(string);
    if (indexOfInput == -1)
    {
        printf("Not found: ?\n");
        return 0;
    }
    if (indexGoal == indexOfInput)
    {
        printf("You entered: %s\n", letters[indexOfInput]);
        return 1;
    }
    else
    {
        printf("You entered: %s\n", letters[indexOfInput]);
        return 0;
    }
}

/**
 * @brief Function to check whether the input
 *          morse code is correct and print as
 *          such
 * @return Returns a boolean based on whether the input was correct or incorrect
 */
int checkCorrect()
{
    int correct = convertArray(grabArray());
    if (correct == 1)
    {
        printf("Correct! Well done!\n");
        return 1;
    }
    else
    {
        printf("Incorrect! Try again!\n");
        return 0;
    }
}

/**
 * @brief Function to control the game loop of
 *          level one and control the lives of the player
 * @return Returns 1 if the player has passed the level, returns -1 if player has failed the level
 */
int levelOne()
{
    printf("Level One!\n");
    lives = 3;
    correctGuesses = 0;
    livesColourChange(); // indicate the gaem has begun
    while (1)
    {
        indexGoal = rand() % 36;
        printf("Please enter the following Character: %s, (Hint the Morse is : %s)\n", letters[indexGoal], morse[indexGoal]);
        input();
        watchdog_update();
        if (checkCorrect() == 1)
        {
            correctGuesses++;
            totalCorrect++;
            if (lives < 3)
            {
                lives++;
                livesColourChange();
            }

            if (correctGuesses == 5)
            {
                return 1;
            }
        }
        else
        {
            lives--;
            livesLost++;
            livesColourChange();

            if (lives == 0)
            {
                return -1;
            }
        }
    }
}

/**
 * @brief Function to control the game loop of
 *          level two and control the lives of the player
 *
 * @return Returns 1 if the player has passed the level, returns -1 if player has failed the level
 */
int levelTwo()
{
    lives = 3;
    correctGuesses = 0;
    printf("You made it to Level two!\n");
    livesColourChange(); // indicate the gaem has begun
    while (1)
    {
        indexGoal = rand() % 36;
        printf("Please enter the following Character: %s\n", letters[indexGoal]);
        input();
        watchdog_update();
        if (checkCorrect())
        {
            correctGuesses++;
            totalCorrect++;
            if (lives < 3)
            {
                lives++;
                livesColourChange();
            }

            if (correctGuesses == 5)
            {
                return 1;
            }
        }
        else
        {
            lives--;
            livesLost++;
            livesColourChange();

            if (lives == 0)
            {
                return -1;
            }
        }
    }
}
// Level three game loop
void levelThree()
{
}
// Level four game loop
void levelFour()
{
}

/**
 * @brief Function to control the overall flow of the game
 *          controlling levels and the game over screen
 *
 */
void controlFunction()
{
    do
    {

        // case and switch to decide levels based on some int
        switch (level)
        {
        case 1:
            if (levelOne() == -1)
            {
                exitGame = 1;
            }
            else
            {
                level++;
            }
            break;

        case 2:
            if (levelTwo() == -1)
            {
                exitGame = 1;
            }
            else
            {
                level++;
                printf("YOU WIN! WELL DONE! \n");
                statistics();
                return;
            }
            break;

        default:
            levelOne();
        }

    } while (exitGame == 0);
    GameOverGraphic();
    statistics();
    return;
}

/**
 * @brief Main entry point for the C program
 *
 */
int main()
{

    // Initialise all STDIO as we will be using the GPIOs
    stdio_init_all();

    srand(time(0));

    // Initialise the PIO interface with the WS2812 code
    uint offset = pio_add_program(pio, &ws2812_program);
    ws2812_program_init(pio, 0, offset, WS2812_PIN, 800000, IS_RGBW);

    // initialise all functions in arm
    main_asm();

    // put blue
    put_pixel(urgb_u32(0x00, 0x00, 0x7F));

    // watchdog
    watchdog_enable(16777215, 0);

    // graphic
    gameGraphic();

    //
    levelInput();

    // control loop
    controlFunction();

    return (0);
}
