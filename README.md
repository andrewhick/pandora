# pandora

## Introduction

Pandora is a pixelly cat game made using the [PICO-8 fantasy console](https://www.lexaloffle.com/pico-8.php), coded in [Lua](https://www.lua.org/).

You can play the game on [andrewhick.com/games](https://www.andrewhick.com/games).

Get through gardens, dungeons and mountains while looking for your long lost socky. Defeat your nemesis. If you're particularly good, you get a medal at the end of each level.

* Controls: up, down left and right :)
* Computer: Z = OK or wait, X = menu
* Mobile: O = OK or wait, X = menu

## Editing

[Buy Pico-8](https://www.lexaloffle.com/pico-8.php) and load the latest .p8 file to edit the game.

## Exporting

To export the game to play on the web in p8.png format:

* Press fn+F7 during the game to capture the image
* Exit the game
* Save the png file with `save pandora.p8.png`
* Export the HTML and Javascript files with `export pandora.html`
* Embed the png on a website, linking to pandora.html
* Remember to `load pandora.p8` again to continue coding.

How it looks on a website:

```html
<a href="./pandora.html">
  <img class="inline" src="./pandora.p8.png" alt="Play pixelly cat game"/>
</a>
```

## Main versions

* 00 - First 6 levels
* 01 - Menu and title screen
* 02 - Ice levels (7-9)
* 03 - All 16 levels completed
* 04 - Hints and level names
* 05 - Music varies by level type
