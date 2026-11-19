# CurseForge project description

This is the text of the CurseForge project page, kept apart from the README (which is written for the
GitHub repository). Paste it into the description editor as Markdown. The screenshots under
`docs/screenshots` are uploaded on the project page by hand.

Summary line for the project form: One-click "inc" calls for battlegrounds in WoW Forever.

---

One-click "inc" calls for battlegrounds in **WoW Forever**. The window shows the bases of the battleground
you are in and selects the one you are standing at. Click **1**, **2**, **3**, **4+** or **Big** and your
team reads `*Inc call* Stables 3 *INC*`. **Clear** tells them the base is safe again.

## What it does

- **Bases per battleground**: Warsong Gulch, Arathi Basin, Alterac Valley and Darkspear Islands. Any other
  battleground uses its map markers.
- **The base you are at is selected for you.** A click selects another one. When you walk away from a base,
  it is deselected again, so a call never goes out for a place you have left.
- **Flag carrier**: in flag battlegrounds, call inc on the flag carrier the same way.
- **Your own buttons and phrases**: add as many call buttons as you like and write your own phrases.
- **No spam**: a short pause after each call, adjustable.
- **Works in combat**: calling and picking a base work while you fight.
- A small window that you can move, half transparent by default.

## Commands

`/inc` shows or hides the window; `/inc options`, `/inc test` (a demo outside a battleground; in a group
it sends to that group, alone it only shows you the call), `/inc reset`, `/inc log`.

## Languages

English and German, following the game client; every other language uses English.

## Problems

The addon catches its errors and tells you in chat. `/inc log` opens a report you can paste into an issue
on GitHub.

## Support Maldö

The addon is free. If you like it:
PayPal https://www.paypal.com/donate/?hosted_button_id=SVZHLRTQ6H4VL ·
Discord https://discord.gg/GbvU9sns5z · Twitch https://www.twitch.tv/maldoe ·
YouTube https://www.youtube.com/@dermaldoe
