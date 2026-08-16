---
title: Your first site, line by line
group: Build & ship
description: This is the actual code for a tiny personal page you can ship as your very first project.
---

# Your first site, line by line

^ This is the actual code for a tiny personal page you can ship as your very first project. Copy it, change the words to be about you, and you've built something real. No experience needed.

## 1. Make the files

Open VS Code, make a new folder (call it whatever, e.g. `my-page`), and inside it create two files: `index.html` and `style.css`.

## 2. The page: `index.html`

Paste this in. It's a whole webpage: a heading, a line about you, and a couple of links.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Your Name</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <main>
    <h1>Hi, I'm Your Name</h1>
    <p>I'm a builder on Pixl. I like making things and I'm just getting started.</p>
    <ul>
      <li><a href="https://github.com/yourname">My GitHub</a></li>
      <li><a href="https://pixl.rsvp">Pixl</a></li>
    </ul>
  </main>
</body>
</html>
```

## 3. The style: `style.css`

HTML on its own looks plain. This makes it look intentional.

```css
body {
  margin: 0;
  min-height: 100vh;
  display: grid;
  place-items: center;
  font-family: system-ui, sans-serif;
  background: #16130d;
  color: #f4e3c2;
}
main { max-width: 32rem; padding: 2rem; }
h1 { font-size: 2.2rem; margin: 0 0 .5rem; }
a { color: #f4b942; }
ul { list-style: none; padding: 0; display: flex; gap: 1rem; }
```

Double-click `index.html` to open it in your browser. That's your site, live on your own machine.

## 4. Make it yours

Change the name, the sentence, and the links. Add a second paragraph, a photo (`<img src="me.png">`), a list of things you've made, whatever. It only has to be real and yours. If you want more tags to play with, the [HTML guide](/docs/html/) covers the basics.

## 5. Track, push, ship

Before you spend real time on it, get [Hackatime](/docs/hackatime/) installed so your hours count. Then push the folder to GitHub (the [Git guide](/docs/git/) has the commands), create the project in your Builder Terminal, and ship it. Full checklist in [Build your first project](/docs/first-project/).

::: note Stuck?
That's normal, everyone is at first. Ask in the Pixl help channel, or just ship the simplest version that works. Finished beats perfect.
:::
