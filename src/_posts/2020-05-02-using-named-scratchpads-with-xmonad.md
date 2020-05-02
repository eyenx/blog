---
layout: post
title: "Using named scratchpads with xmonad"
description: ""
category: howto
tags: [haskell,xmonad,windowmanager]
disqus: y
---

This will be a quick one. I always loved how i3 has the [scratchpad feature](https://i3wm.org/docs/userguide.html#_scratchpad) and wanted to use this also with my [xmonad](https://xmonad.org) setup.

It didn't took me too long, to find out there is the [`XMonad.Util.NamedScratchpad`](https://hackage.haskell.org/package/xmonad-contrib-0.13/docs/XMonad-Util-NamedScratchpad.html) package which can be used to set up a number of scratchpads running different applications.

## Configuration

First of all, import the package in your `xmonad.hs`

```haskell
import XMonad.Util.NamedScratchpad
```

Now we just need to write following code block to configure some scratchpads. As an example, I'll set up 3 different scratchpads.

* taskwarrior
* simple terminal
* pavucontrol

```haskell
-- scratchPads
scratchpads :: [NamedScratchpad]
scratchpads = [
-- run htop in xterm, find it by title, use default floating window placement
    NS "taskwarrior" "urxvtc -name taskwarrior -e ~/bin/tw" (resource =? "taskwarrior")
        (customFloating $ W.RationalRect (2/6) (2/6) (2/6) (2/6)),

    NS "term" "urxvtc -name scratchpad" (resource =? "scratchpad")
        (customFloating $ W.RationalRect (3/5) (4/6) (1/5) (1/6)),

    NS "pavucontrol" "pavucontrol" (className =? "Pavucontrol")
        (customFloating $ W.RationalRect (1/4) (1/4) (2/4) (2/4))
  ]

```

I will make use of the `classname` or `resource` of the window metadata to map them correctly. You can find out about those informations with a tool like [`xprop`](https://linux.die.net/man/1/xprop).

```bash
xprop | grep WM_CLASS
```

Now you only need to select a window to find out it's `WM_CLASS`.

![xprop](/img/p/20200502_1.gif)

The last thing to do is to set up the keybindings and add the scratchpads to the `manageHook`:

```haskell
-- scratchPad term
, ("M-S-\\", namedScratchpadAction scratchpads "term")
-- scratchPad taskwarrior
, ("M-S-t", namedScratchpadAction scratchpads "taskwarrior")
-- scratchPad pavucontrol
, ("M-v", namedScratchpadAction scratchpads "pavucontrol")
```

```haskell
main = do
  xmonad $ def {
  ,manageHook = (myManageHook <+> namedScratchpadManageHook scratchpads
  }
```

See [my xmonad.hs](https://github.com/eyenx/dotfiles/blob/master/.xmonad/xmonad.hs) for more details.



## Terminals and their WM_CLASS

As you can see from my [gif](/img/p/20200502_1.gif), the terminal I am using is URxvt. All of my terminals will have the Classname `URxvt` so it seems impossible to get a named scratchpad working with a terminal running a specific application (a.e. Taskwarrior), because all `URxvt`terminals will have the same `WM_CLASS`.

This is where the `-name` parameter comes into play. Thanks to this additional parameter a specific name get's set as additional `WM_CLASS` and I can use it to identify my scratchpads.

## W.RationalRect?

At last you should consider making usage of `XMonad.StackSet.RationalRect`:

```haskell
import XMonad.StackSet as W
```

This gives you the ability to predefine the structure of the window geometry of your scratchpads.

This means, `RationalRect (3/5) (4/6) (1/5) (1/6)` would start drawing my scratchpad window at 3/5 of my x axis, and at 4/6 of my y axis. The window will then be 1/5 of my x axis in width and 1/6 of my y axis in height. This is super useful if you aren't using the same resolution all the time.

Read more about [`RationalRect` here](https://hackage.haskell.org/package/xmonad-0.15/docs/XMonad-StackSet.html#t:RationalRect) and don't hesitate to [contact](https://eyenx.ch/about) me if something is unclear. I'm no Haskell or XMonad expert, but I'll do my best to help you out.
