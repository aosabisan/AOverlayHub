AOVERLAY HUB 1.1.1
==================
Made and distributed by Aosabi 「青錆竜也」 (aosabi@pm.me).
Use of this program is covered by LICENSE.txt.

All your stream overlays in one place. AOverlay Hub shows every overlay through
ONE Browser source in ONE OBS scene. Put that scene into any scene you want the
overlays in, and change everything (position, size, scroll speed, direction,
horizontal or vertical, colours, fonts, outlines, shadows...) from one control
panel. Nothing else has to stay open in a web browser while you stream.

Quick install steps are in INSTALL.txt.


WHAT'S NEW IN 1.1.1
-------------------
- The song detection of AOverlay for Stream Music is now built in. Now Playing
  finds the song from VLC, the Spotify app, Suno, Spotify's web player and
  SoundCloud by itself: no second program, no second tray icon, no download
  from another page. Players, names, VLC details and the browser connector
  are in More > Music. If you used the separate AOverlay for Stream Music, the
  control panel offers to copy its settings and the look of its overlay; after
  that you can uninstall it.
- One Start menu folder, "AOverlay", with one launcher, "AOverlay" (the control
  panel), and "Uninstall AOverlay".


WHAT'S NEW IN 1.1
-----------------
- Emote Combo and Emote Rain are built in (no website needed, no lag).
- Banners: ready-made graphics or your own picture, with text on top.
- Full text styling everywhere: any installed font (TrueType and OpenType),
  size, colour, outline (thickness, fade, see-through), shadow (colour,
  distance, angle, fade, see-through), each with its own see-through slider.
- Chat fills whatever size its box is, shows usernames in their platform
  colour, shows platform logos, and can hide chosen users (like bot accounts).
- Auto-hide: the Support Ticker can stay hidden until the first support of
  the stream, or after a while without support. Chat can hide after a while
  without messages.
- Rumble: rants, subs, gifted subs, follows AND chat.
- Spam phrase moderation for Kick, Twitch and YouTube through Streamer.bot,
  managed from the new Moderation tab.
- Profiles: several layouts, each shown in OBS through its own scene.
- Undo/Redo (Ctrl+Z / Ctrl+Y) and "Save this position" for every overlay.


WHAT YOU CAN ADD
----------------
Built in:
  Support Ticker  - a scrolling (or still) list of support: Kicks, Bits, Super
                    Chats, Super Stickers, Rumble Rants, donations, subs, resubs,
                    gifted subs, YouTube memberships (and follows, if you want).
                    Horizontal strip or vertical list, any direction, themes,
                    today's totals, platform letters or logos.
  Delayed Chat    - Kick, Twitch, YouTube and Rumble chat in one box. Messages
                    wait a few seconds first, so anything deleted by mods,
                    AutoMod or the spam moderation, and banned users, never
                    reach the screen.
  Now Playing     - the song that's playing (VLC, Spotify, Suno, SoundCloud,
                    found by AOverlay itself) or read from a text file.
  Emote Combo     - counts emotes as chat uses them: "x7" next to each one,
                    rows appear and fade away.
  Emote Rain      - emotes from chat fall (or rise, or fly sideways) across
                    the screen; every emote, or only when a combo builds up.
  Banner          - a graphic with text: pick one of 10 ready-made designs and
                    its colours, or use your own picture (PNG, JPG, GIF, WebP,
                    APNG or SVG). Several lines can take turns or scroll.

Web widgets (paste their link):
  Streamer.bot's chat overlay (set up for you), Streamlabs widgets (alert box,
  event list, goals...), StreamElements overlays, or any other overlay link.

Local files:
  An HTML overlay page or picture saved on your computer.

You can add as many overlays as you like, including several of the same kind.


THE CONTROL PANEL
-----------------
Open it from the Start menu (AOverlay), or double-click the AOverlay icon
by the clock.

  Overlays tab
    Left:    the overlays in this profile. The top of the list is drawn on
             top; use the arrows to change the order, the eye to show or hide.
    Middle:  a preview of your screen. Drag an overlay to move it, drag its
             corners or edges to resize. Arrow keys nudge it (Shift = 10px).
             "Preview background..." puts a screenshot of your game behind
             the preview to line things up.
    Right:   everything about the selected overlay. "Save this position"
             remembers where it is; "Go back to saved position" puts it back.

  Moderation tab
    The spam phrase list and its settings (see MODERATION below).

  Top
    Profile          which layout you're editing (see PROFILES).
    Coloured dots    what's connected: Helper, OBS stage, Streamer.bot,
                     Kick chat, Rumble.
    Undo / Redo      Ctrl+Z and Ctrl+Y also work.
    Test             send a test supporter, chat message or emotes.
    More             Connections (Streamer.bot, Kick, Rumble, OBS), set up
                     OBS, screen size, "New stream", reload the overlays in
                     OBS, clear the supporter list, reset today's totals,
                     save/load settings to a file, help, quit.


PROFILES
--------
A profile is a complete layout: its own overlays, positions and styles. Make
one for gaming, one for just chatting, and so on (Profiles... at the top:
new, duplicate, rename, delete).

Each profile is shown in OBS by its own scene, called
"AOverlay Hub - <profile name>". Use "Set up in OBS" for each profile, then
add whichever profile's scene you want into each of your OBS scenes.

Connections, the supporter list and moderation are shared by all profiles.
To copy one overlay into another profile, use "Copy to another profile..."
at the bottom of its settings.


TEXT STYLE
----------
Every overlay with text has a Text section:
  Font             every font installed on this computer, each shown in its
                   own look. Type to search. TrueType (.ttf) and OpenType
                   (.otf) fonts both work. A font installed while the helper
                   is running appears after AOverlay Hub is restarted.
  Size, bold, italic, colour, letters see-through
  Outline          colour, thickness, fade (soft edge), see-through
  Shadow           colour, distance, direction, fade length, see-through
OBS shows fonts installed on the same computer. If you move your settings to
another computer, install the same fonts there too.


AUTO-HIDE
---------
Support Ticker:
  "Hide until the first support of the stream" - stays hidden until someone
  supports. A new stream is noticed when Streamer.bot reports that you went
  live; you can also press More > New stream.
  "Hide after ... minutes without support" (0 = never).
Delayed Chat:
  "Hide after ... seconds without messages" (0 = never). It comes back with
  the next message.


EMOTES
------
Emote Combo and Emote Rain read emotes straight from the chat AOverlay Hub
already gets: Kick directly, Twitch and YouTube through Streamer.bot, and
Rumble. No browser or website has to stay open.
If you already have your own Streamer.bot actions that broadcast
"EmoteCount" or "EmoteDrop" messages, tick the "Also count/drop ... messages
sent by a Streamer.bot action" option in the overlay's settings.


MODERATION
----------
AOverlay Hub comes with a starter list of common spam-bot phrases. When a
chatter says one, the Streamer.bot action:
  - deletes the message (Kick and Twitch; YouTube can't delete through
    Streamer.bot, so there it only times out or bans),
  - times the chatter out (you choose how long) or bans them.
Matching ignores capital letters, punctuation and extra spaces.
Safe: you, moderators, VIPs (and Kick OG badges), and chatters who have sent
a number of normal messages (you choose how many). Rumble can't be moderated:
its API is read-only.

In the Moderation tab:
  - add, edit (click the text), turn on/off (one click) and delete phrases,
  - search the list or show only some kinds,
  - see new phrases appear live (they flash) when the Streamer.bot
    action learns them,
  - see the most recent timeouts and bans.

Learning: when you or a mod bans someone who had sent fewer than 4 chat
messages in total (a typical spam bot), their FIRST message is added to the
list (if it's long enough). People with more messages are never learned from.
The limit of 4 can be changed. Messages are counted by the Streamer.bot action
while it runs, so someone who chatted before you imported it looks new at
first. "Say so in chat" is off by default; when you turn it on you choose
what the bot says ({undo} becomes your undo command, {user} the banned name).

Chat commands for you and mods (can be turned off). These are the standard
words; each one can be changed in the Moderation tab:
  !addphrase <text>        add a phrase
  !delphrase <text>        remove a phrase
  !undophrase              remove the last phrase that was added
  !phrasemode ban|timeout  switch between banning and timing out

Installing the Streamer.bot actions (one time):
  1. Moderation tab > "Download for Streamer.bot" (or "Copy import text").
  2. In Streamer.bot press "Import" at the top, drop the file in (or paste
     the text) and press Import. Two actions appear in the group
     "AOverlay Hub": "AOverlay Hub - Spam Phrase Moderation" and
     "AOverlay Hub - Learn Phrase From Ban".
  3. If you had other spam-phrase actions before, turn them off so nobody is
     timed out twice. A list from an older action stored in Streamer.bot's
     global "learnedPhrases" is brought over automatically the first time.
  The actions get their settings and the phrase list from AOverlay Hub, so
  everything is changed in the Moderation tab, not in Streamer.bot. They
  need AOverlay Hub to be running. If AOverlay Hub ever has to use a port
  other than 8096, download and import the file again.

The chat delay for each Delayed Chat overlay is also in the Moderation tab:
2-3 seconds is usually enough for spam to be removed before it's shown.


STREAMER.BOT
------------
Streamer.bot passes support events (Kicks, Bits, Super Chats, subs, donations)
and Twitch/YouTube chat to AOverlay Hub, and runs the moderation. Turn on its
WebSocket server once:
  Streamer.bot > Servers/Clients > WebSocket Server > tick "Auto Start",
  press "Start Server". Keep 127.0.0.1 and port 8080 unless you need others.
If you set a password there, type it into AOverlay Hub (More > Connections).
Kick needs Streamer.bot 1.0 or newer. Donation services (Streamlabs,
StreamElements, Ko-fi, TipeeeStream, Fourthwall) only work if they're
connected inside Streamer.bot.


KICK CHAT
---------
Chat and emotes from Kick come straight from Kick. They need your Kick
chatroom number: More > Connections > Kick, type your channel name and press
"Find chatroom". If Kick doesn't allow the lookup:
  1. Open https://kick.com/api/v2/channels/YOURCHANNEL in your web browser.
  2. Press Ctrl+F and search for: chatroom
  3. Right after it you'll see "id": and a number. That's your chatroom number.


RUMBLE
------
1. Go to https://rumble.com/account/livestream-api (signed in) and create a
   Live Stream API link. Treat it like a password: anyone with it can read
   your stream data. You can reset it there at any time.
2. Paste it into More > Connections > Rumble and press "Test the Rumble link".
Rants, new subs, gifted subs, follows and chat show up while you're live.
Support from before AOverlay Hub first read the link is not replayed.

Rumble's API gives chat every few seconds ("Check every"). For chat that
appears the moment it's sent, tick "Faster Rumble chat (live feed)". That
reads Rumble's own chat feed, which isn't an official API: it only reads, but
it could stop working if Rumble changes it. If it stops, AOverlay Hub falls
back to the API by itself.


PLATFORM LOGOS
--------------
Chat and the ticker can show each platform's logo. The logos are loaded from
the platforms' own websites, so they need an internet connection; without
one a coloured dot is shown instead. You can also choose your own pictures
("My own pictures" under the icon setting).


NOW PLAYING
-----------
Song source:
  Built in - AOverlay finds the song itself. It looks at VLC, the Spotify app,
      and Suno, Spotify's web player and SoundCloud in your web browser. It
      only looks while a Now Playing overlay is on, and nothing leaves your
      computer.
  A text file - many music programs can write the current song into a text
      file. Type that file's full path.
  Off

Players and names (More > Music in the control panel):
  Untick a player to ignore it, and change what each is called on screen
  (empty = just the song). "Add the artist" puts the artist after the song
  name when the player tells us. Shared by every Now Playing overlay.
  The look (font, colours, outline, background, scrolling, the text between
  several songs...) is set per overlay, like every other overlay.

VLC: works as it is (the song is read from VLC's title bar). To also know
  when a song is paused, turn on VLC's web interface: Tools > Preferences,
  Show settings: All, Interface > Main interfaces, tick Web, then set a
  password under Main interfaces > Lua. AOverlay reads VLC's own settings.

Spotify: the desktop app works with no setup. Spotify's web player needs the
  browser connector.

Suno and SoundCloud: seen while their tab is the visible tab. For all the
  time, even in a background tab, use the browser connector.

Browser connector (once per browser): More > Music shows three steps. You
  install Tampermonkey (a free browser add-on), open AOverlay's connector link
  and press Install, then reload your music tab. The panel says "working" when
  it is. If you had the older AOverlay for Stream Music connector, delete it in
  Tampermonkey.

Text file for other programs: More > Music > "Also write the current song to
  a text file" keeps the song in nowplaying.txt in AOverlay's settings folder.

Moving from the separate AOverlay for Stream Music: open the control panel;
  it offers to copy that program's settings. Then uninstall it from Windows'
  Settings > Apps (it isn't needed any more, and two programs watching the same
  players only wastes power).


OBS
---
"Set up in OBS" (in the setup wizard, Profiles..., or More) makes one scene
called "AOverlay Hub - <profile name>" with one Browser source in it, and
adds that scene to the scenes you pick. Your other sources aren't touched.
To add the overlays to another scene later: select the scene, press + under
Sources, choose "Scene", and pick the AOverlay Hub scene.

By hand: Profiles... > "Copy OBS link" for the profile. In OBS make a scene,
add a Browser source, untick "Local file", paste the link as the URL, set
Width and Height to your OBS canvas (Settings > Video > Base Resolution),
and tick "Control audio via OBS" (so alert sounds show in the OBS mixer).


IF SOMETHING DOESN'T SHOW UP
----------------------------
- AOverlay Hub must be running while you stream (icon by the clock). The
  installer can start it with Windows for you.
- "OBS stage" dot not lit: in OBS, right-click the AOverlay Hub Browser
  source > Properties and check the URL, or use More > Reload the overlays
  in OBS.
- Streamer.bot dot not lit: is Streamer.bot open, with its WebSocket server
  started? Is the password right?
- Support Ticker missing: is "Hide until the first support" on? Send a test
  supporter, or turn that option off.
- Web widgets only appear as boxes in the preview unless you tick "Show web
  widgets in the preview". They always show for real in OBS.
- Port 8096 already used by another program: AOverlay Hub picks the next
  free port and shows it in the control panel's address. Run "Set up in OBS"
  again so OBS uses the new address, and import the Streamer.bot actions
  again.
- A log file is in %APPDATA%\AOverlay Hub\hub.log (tray icon > Open
  settings folder).


YOUR SETTINGS
-------------
Kept in %APPDATA%\AOverlay Hub (settings, supporter list, phrase list, and
pictures you chose). "More > Save settings to a file" makes a backup. That
file contains your passwords and widget links, so keep it private.
Settings from AOverlay Hub 1.0 are moved over by themselves into a profile
called "Main". Botrix widgets from 1.0 are kept as plain web links; replace
them with the built-in Emote Combo and Emote Rain.


CREDITS AND LICENSE
-------------------
AOverlay Hub is made and distributed by Aosabi 「青錆竜也」.
Contact: aosabi@pm.me
Copyright (c) 2026 Aosabi 「青錆竜也」. All Rights Reserved.
You may use it for free, including on streams that earn money. You may not
share, sell, change or reuse it, or present it as your own: the full terms are
in LICENSE.txt (also in the control panel: the "License" link at the bottom
left, or More > Help).


UNINSTALL
---------
Settings > Apps > Installed apps > AOverlay Hub > Uninstall, or "Uninstall
AOverlay" in the Start menu (folder "AOverlay"). It asks whether to keep your settings. The
AOverlay Hub scenes in OBS and the actions in Streamer.bot are left alone;
delete them there if you like.
