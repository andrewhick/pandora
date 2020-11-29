# pandora

## Introduction

Pandora is a pixelly cat game made using the [PICO-8 fantasy console](https://www.lexaloffle.com/pico-8.php).

You can play the game on [andrewhick.com/games](https://www.andrewhick.com/games).

Explore each level while looking for your long lost socky. You get a medal if you have time to spare at the end.

* Controls: up, down left and right :)
* Select: X on mobile, Z on computer
* Menu: O on mobile, X on computer

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
