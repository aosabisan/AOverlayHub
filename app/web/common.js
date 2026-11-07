/*
  AOverlay Hub - shared definitions (used by the stage and the control panel).
  Copyright (c) 2026 Aosabi 「青錆竜也」 aosabi@pm.me. All Rights Reserved. See LICENSE.txt.
*/
(function (root) {
  "use strict";

  var VERSION = "1.1.0";

  function clone(o) { return o === undefined ? undefined : JSON.parse(JSON.stringify(o)); }

  // Fills in anything missing in "obj" from "defaults" (deep), without touching what's there.
  function fillDefaults(obj, defaults) {
    if (obj === null || typeof obj !== "object" || Array.isArray(obj)) return clone(defaults);
    Object.keys(defaults).forEach(function (k) {
      var d = defaults[k];
      if (!(k in obj) || obj[k] === undefined || obj[k] === null) obj[k] = clone(d);
      else if (d && typeof d === "object" && !Array.isArray(d)) obj[k] = fillDefaults(obj[k], d);
    });
    return obj;
  }
  function getPath(o, path) {
    var p = path.split(".");
    for (var i = 0; i < p.length; i++) { if (o == null) return undefined; o = o[p[i]]; }
    return o;
  }
  function setPath(o, path, v) {
    var p = path.split(".");
    for (var i = 0; i < p.length - 1; i++) {
      if (o[p[i]] == null || typeof o[p[i]] !== "object") o[p[i]] = {};
      o = o[p[i]];
    }
    o[p[p.length - 1]] = v;
  }
  function rgba(hex, a) {
    var h = String(hex || "#000000").replace("#", "");
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    var n = parseInt(h.slice(0, 6), 16);
    if (!isFinite(n)) n = 0;
    if (a === undefined || a === null) a = 1;
    return "rgba(" + ((n >> 16) & 255) + "," + ((n >> 8) & 255) + "," + (n & 255) + "," + Math.max(0, Math.min(1, a)) + ")";
  }
  function fontStack(name) {
    var n = String(name || "").replace(/["\\;{}<>]/g, "").trim();
    return (n ? '"' + n + '", ' : "") + '"Segoe UI", Roboto, Arial, sans-serif';
  }

  /* =====================================================================
     Text style (same options everywhere text is drawn)
     Each part (letters, outline, shadow) is its own layer, so each has its own see-through level.
     ===================================================================== */
  var TEXT = {
    font: "Segoe UI", size: 22, bold: true, italic: false,
    color: "#ffffff", see: 0,
    outline: false, outlineColor: "#000000", outlineWidth: 3, outlineFade: 1, outlineSee: 0,
    shadow: true, shadowColor: "#000000", shadowDistance: 2, shadowAngle: 135, shadowFade: 3, shadowSee: 10
  };
  function textStyle(over) { return fillDefaults(clone(over || {}), TEXT); }
  // Form fields for a text style stored at settings[key].
  function textFields(key, opts) {
    opts = opts || {};
    var k = function (x) { return key + "." + x; };
    var on = function (x) { return function (s) { return !!getPath(s, key + "." + x); }; };
    var f = [
      { k: k("font"), label: "Font", t: "font" },
      { k: k("size"), label: "Text size", t: "range", min: 8, max: opts.maxSize || 120, step: 1, unit: "px" },
      { k: k("bold"), label: "Bold", t: "check" },
      { k: k("italic"), label: "Italic", t: "check" }
    ];
    if (!opts.noColor) f.push({ k: k("color"), label: opts.colorLabel || "Text colour", t: "color" });
    f.push({ k: k("see"), label: "Letters see-through", t: "range", min: 0, max: 100, step: 1, unit: "%" });
    f.push({ k: k("outline"), label: "Outline around the letters", t: "check" });
    f.push({ k: k("outlineColor"), label: "Outline colour", t: "color", show: on("outline") });
    f.push({ k: k("outlineWidth"), label: "Outline thickness", t: "range", min: 1, max: 20, step: 0.5, unit: "px", show: on("outline") });
    f.push({ k: k("outlineFade"), label: "Outline fade", t: "range", min: 0, max: 20, step: 0.5, unit: "px", show: on("outline") });
    f.push({ k: k("outlineSee"), label: "Outline see-through", t: "range", min: 0, max: 100, step: 1, unit: "%", show: on("outline") });
    f.push({ k: k("shadow"), label: "Drop shadow", t: "check" });
    f.push({ k: k("shadowColor"), label: "Shadow colour", t: "color", show: on("shadow") });
    f.push({ k: k("shadowDistance"), label: "Shadow distance", t: "range", min: 0, max: 40, step: 0.5, unit: "px", show: on("shadow") });
    f.push({ k: k("shadowAngle"), label: "Shadow direction", t: "range", min: 0, max: 359, step: 1, unit: "\u00b0", show: on("shadow"), help: "0\u00b0 = right, 90\u00b0 = down, 180\u00b0 = left, 270\u00b0 = up." });
    f.push({ k: k("shadowFade"), label: "Shadow fade length", t: "range", min: 0, max: 40, step: 0.5, unit: "px", show: on("shadow") });
    f.push({ k: k("shadowSee"), label: "Shadow see-through", t: "range", min: 0, max: 100, step: 1, unit: "%", show: on("shadow") });
    return f;
  }
  function textSection(title, key, opts) { return { title: title, fields: textFields(key, opts) }; }
  // Background box options used by several overlays.
  function bgFields(prefix) {
    var k = function (x) { return (prefix ? prefix + "." : "") + x; };
    return [
      { k: k("bgOn"), label: "Background box", t: "check" },
      { k: k("bgColor"), label: "Background colour", t: "color", show: function (s) { return !!getPath(s, k("bgOn")); } },
      { k: k("bgSee"), label: "Background see-through", t: "range", min: 0, max: 100, step: 1, unit: "%", show: function (s) { return !!getPath(s, k("bgOn")); } },
      { k: k("radius"), label: "Corner roundness", t: "range", min: 0, max: 60, step: 1, unit: "px" }
    ];
  }

  /* ---------------- Support Ticker themes ---------------- */
  var THEMES = {
    classic: { label: "Classic green", colors: { panel: "#0e121a", item: "#1b2230", accent: "#3ddc84", name: "#ffffff", amount: "#3ddc84", title: "#ffffff", grad1: "#3ddc84", grad2: "#2bd9c7", grad3: "#7c5cff" }, panelOpacity: 0.93, itemOpacity: 1 },
    neon:    { label: "Neon",          colors: { panel: "#0b0016", item: "#1a0533", accent: "#ff2bd6", name: "#ffffff", amount: "#39f3ff", title: "#ffffff", grad1: "#ff2bd6", grad2: "#8a2bff", grad3: "#39f3ff" }, panelOpacity: 0.9, itemOpacity: 1 },
    minimal: { label: "Minimal",       colors: { panel: "#000000", item: "#000000", accent: "#ffffff", name: "#ffffff", amount: "#d6d6d6", title: "#ffffff", grad1: "#ffffff", grad2: "#bdbdbd", grad3: "#7a7a7a" }, panelOpacity: 0.55, itemOpacity: 0.35 },
    glass:   { label: "Glass",         colors: { panel: "#ffffff", item: "#ffffff", accent: "#9be7ff", name: "#ffffff", amount: "#9be7ff", title: "#ffffff", grad1: "#9be7ff", grad2: "#c3a6ff", grad3: "#ffffff" }, panelOpacity: 0.12, itemOpacity: 0.14 },
    light:   { label: "Light",         colors: { panel: "#f4f6fa", item: "#ffffff", accent: "#2f80ed", name: "#1b2230", amount: "#2f80ed", title: "#1b2230", grad1: "#2f80ed", grad2: "#56ccf2", grad3: "#9b51e0" }, panelOpacity: 0.96, itemOpacity: 1 },
    sunset:  { label: "Sunset",        colors: { panel: "#1a0f14", item: "#2a1820", accent: "#ff8a3d", name: "#ffffff", amount: "#ffb36b", title: "#ffffff", grad1: "#ff5f6d", grad2: "#ff8a3d", grad3: "#ffc371" }, panelOpacity: 0.92, itemOpacity: 1 }
  };

  /* ---------------- Banner presets (files in web/banners/, colours set by the user) ---------------- */
  var BANNERS = {
    plate:   { label: "Plate",          file: "plate.svg" },
    ribbon:  { label: "Ribbon",         file: "ribbon.svg" },
    glass:   { label: "Glass bar",      file: "glass.svg" },
    neon:    { label: "Neon frame",     file: "neon.svg" },
    pill:    { label: "Gradient pill",  file: "pill.svg" },
    tag:     { label: "Tag",            file: "tag.svg" },
    bubble:  { label: "Speech bubble",  file: "bubble.svg" },
    brush:   { label: "Brush stroke",   file: "brush.svg" },
    slant:   { label: "Slanted bar",    file: "slant.svg" },
    corners: { label: "Corner frame",   file: "corners.svg" }
  };

  var ORIENT = [["horizontal", "Horizontal"], ["vertical", "Vertical"]];
  var DIR_H = [["left", "Left"], ["right", "Right"]];
  var DIR_V = [["up", "Up"], ["down", "Down"]];
  function isH(s) { return s.orientation !== "vertical"; }
  var PLATFORM_FIELDS = function (prefix) {
    return [
      { k: prefix + ".kick", label: "Kick", t: "check" },
      { k: prefix + ".twitch", label: "Twitch", t: "check" },
      { k: prefix + ".youtube", label: "YouTube", t: "check" },
      { k: prefix + ".rumble", label: "Rumble", t: "check" }
    ];
  };

  /* =====================================================================
     Overlay types
     ===================================================================== */
  var TYPES = {
    ticker: {
      label: "Support Ticker",
      blurb: "Scrolling list of tips, Kicks, Bits, Super Chats, Rants, subs and gifted subs.",
      box: { w: 1200, h: 64, x: 360, y: 1000 },
      defaults: {
        motion: "scroll", orientation: "horizontal", direction: "left", speed: 60, max: 20,
        showTitle: true, title: "SUPPORT", titleIcon: "\u2665", emptyText: "Thank you for the support!",
        theme: "classic", colors: clone(THEMES.classic.colors), panelOpacity: 0.93, itemOpacity: 1,
        badges: { show: true, style: "letter", kick: "#53fc18", twitch: "#9146ff", youtube: "#ff1f3d", rumble: "#85c742", donation: "#f5b301" },
        text: { font: "Segoe UI", size: 16, bold: true, shadow: false },
        radius: 12, gap: 12, glowSeconds: 6, showTotals: false, totalsLabel: "Today",
        platforms: { kick: true, twitch: true, youtube: true, rumble: true, donations: true },
        events: { tips: true, subs: true, resubs: true, gifts: true, members: true, follows: false },
        min: { kicks: 0, bits: 0, money: 0 },
        hideUntilFirst: false, hideAfterMinutes: 0
      },
      form: [
        { title: "Movement", fields: [
          { k: "motion", label: "Movement", t: "select", opts: [["scroll", "Scroll"], ["static", "Still (newest first)"]] },
          { k: "orientation", label: "Layout", t: "select", opts: ORIENT, help: "Horizontal is a strip; vertical is a column (like a list)." },
          { k: "direction", label: "Scroll direction", t: "select", opts: DIR_H, show: function (s) { return s.motion === "scroll" && isH(s); } },
          { k: "direction", label: "Scroll direction", t: "select", opts: DIR_V, show: function (s) { return s.motion === "scroll" && !isH(s); } },
          { k: "speed", label: "Scroll speed", t: "range", min: 5, max: 300, step: 5, unit: "px/s", show: function (s) { return s.motion === "scroll"; } },
          { k: "max", label: "Supporters to keep", t: "number", min: 1, max: 100 },
          { k: "glowSeconds", label: "New support glows for", t: "number", min: 0, max: 60, unit: "seconds" }
        ]},
        { title: "Hide automatically", fields: [
          { k: "hideUntilFirst", label: "Hide until the first support of the stream", t: "check", help: "The stream starts when Streamer.bot says you went live, or when you press More > New stream." },
          { k: "hideAfterMinutes", label: "Hide when there's been no new support for", t: "number", min: 0, max: 600, unit: "minutes (0 = never)" }
        ]},
        { title: "Look", fields: [
          { k: "theme", label: "Theme", t: "theme" },
          { k: "radius", label: "Corner roundness", t: "range", min: 0, max: 30, step: 1, unit: "px" },
          { k: "gap", label: "Space between entries", t: "range", min: 0, max: 60, step: 1, unit: "px" },
          { k: "colors.panel", label: "Background", t: "color" },
          { k: "panelOpacity", label: "Background see-through", t: "range", min: 0, max: 1, step: 0.01, pct: true, invert: true },
          { k: "colors.item", label: "Entry background", t: "color" },
          { k: "itemOpacity", label: "Entry see-through", t: "range", min: 0, max: 1, step: 0.01, pct: true, invert: true },
          { k: "colors.accent", label: "Entry edge", t: "color" },
          { k: "colors.name", label: "Name colour", t: "color" },
          { k: "colors.amount", label: "Amount colour", t: "color" }
        ]},
        textSection("Text", "text", { noColor: true, maxSize: 60 }),
        { title: "Label", fields: [
          { k: "showTitle", label: "Show label", t: "check" },
          { k: "title", label: "Label text", t: "text", show: function (s) { return s.showTitle; } },
          { k: "titleIcon", label: "Label icon", t: "text", help: "Any symbol or emoji, or leave empty.", show: function (s) { return s.showTitle; } },
          { k: "colors.title", label: "Label colour", t: "color", show: function (s) { return s.showTitle; } },
          { k: "colors.grad1", label: "Label stripe colour 1", t: "color", show: function (s) { return s.showTitle; } },
          { k: "colors.grad2", label: "Label stripe colour 2", t: "color", show: function (s) { return s.showTitle; } },
          { k: "colors.grad3", label: "Label stripe colour 3", t: "color", show: function (s) { return s.showTitle; } },
          { k: "emptyText", label: "Text before anyone supports", t: "text" },
          { k: "showTotals", label: "Show today's totals", t: "check" },
          { k: "totalsLabel", label: "Totals label", t: "text", show: function (s) { return s.showTotals; } }
        ]},
        { title: "Platform badges", fields: [
          { k: "badges.show", label: "Show platform badges", t: "check" },
          { k: "badges.style", label: "Badge style", t: "select", opts: [["letter", "Coloured letter"], ["logo", "Platform's own site icon"]], show: function (s) { return s.badges.show; } },
          { k: "badges.kick", label: "Kick", t: "color", show: function (s) { return s.badges.show; } },
          { k: "badges.twitch", label: "Twitch", t: "color", show: function (s) { return s.badges.show; } },
          { k: "badges.youtube", label: "YouTube", t: "color", show: function (s) { return s.badges.show; } },
          { k: "badges.rumble", label: "Rumble", t: "color", show: function (s) { return s.badges.show; } },
          { k: "badges.donation", label: "Donations", t: "color", show: function (s) { return s.badges.show; } }
        ]},
        { title: "What to show", fields: [
          { k: "platforms.kick", label: "Kick", t: "check" },
          { k: "platforms.twitch", label: "Twitch", t: "check" },
          { k: "platforms.youtube", label: "YouTube", t: "check" },
          { k: "platforms.rumble", label: "Rumble", t: "check" },
          { k: "platforms.donations", label: "Donations (Streamlabs, StreamElements, Ko-fi, TipeeeStream, Fourthwall)", t: "check" },
          { k: "events.tips", label: "Kicks, Bits, Super Chats, Rants, donations", t: "check" },
          { k: "events.subs", label: "New subs", t: "check" },
          { k: "events.resubs", label: "Resubs", t: "check" },
          { k: "events.gifts", label: "Gifted subs and memberships", t: "check" },
          { k: "events.members", label: "YouTube members", t: "check" },
          { k: "events.follows", label: "Rumble follows", t: "check" },
          { k: "min.kicks", label: "Smallest Kicks to show", t: "number", min: 0 },
          { k: "min.bits", label: "Smallest Bits to show", t: "number", min: 0 },
          { k: "min.money", label: "Smallest money amount to show", t: "number", min: 0, step: 0.5 }
        ]}
      ]
    },

    chat: {
      label: "Delayed Chat",
      blurb: "Kick, Twitch, YouTube and Rumble chat. Kick messages wait a few seconds, so deleted messages and banned users never reach the screen.",
      box: { w: 520, h: 640, x: 30, y: 300 },
      defaults: {
        sources: { kick: true, twitch: true, youtube: true, rumble: true },
        kickDelay: 3, sbDelay: 0, rumbleDelay: 0, fade: 0, max: 0, hideCommands: false, hideUsers: "",
        autoHideSeconds: 0,
        layout: "stack", newestAt: "bottom",
        icons: "logo", iconUrls: { kick: "", twitch: "", youtube: "", rumble: "" },
        avatars: true, badges: true, nameColors: "platform", nameColor: "#ffffff",
        text: { font: "Segoe UI", size: 22, bold: false, shadow: true },
        bubble: "#000000", bubbleSee: 45, radius: 10, gap: 6,
        kickColor: "#53fc18", twitchColor: "#a970ff", youtubeColor: "#ff3b3b", rumbleColor: "#85c742"
      },
      form: [
        { title: "Where chat comes from", fields: PLATFORM_FIELDS("sources").concat([
          { k: "_kickinfo", t: "note", text: "Kick connects directly using the Kick chatroom in More > Connections. Twitch and YouTube come through Streamer.bot. Rumble uses the Rumble link in More > Connections." }
        ])},
        { title: "Delay and timing", fields: [
          { k: "kickDelay", label: "Hold Kick messages for", t: "number", min: 0, max: 60, step: 0.5, unit: "seconds" },
          { k: "sbDelay", label: "Hold Twitch/YouTube messages for", t: "number", min: 0, max: 60, step: 0.5, unit: "seconds" },
          { k: "rumbleDelay", label: "Hold Rumble messages for", t: "number", min: 0, max: 60, step: 0.5, unit: "seconds" },
          { k: "fade", label: "Messages disappear after", t: "number", min: 0, max: 600, unit: "seconds (0 = never)" },
          { k: "max", label: "Most messages on screen", t: "number", min: 0, max: 200, unit: "(0 = as many as fit)" },
          { k: "autoHideSeconds", label: "Hide the chat when nobody has chatted for", t: "number", min: 0, max: 3600, unit: "seconds (0 = never)" }
        ]},
        { title: "Who to hide", fields: [
          { k: "hideCommands", label: "Hide messages starting with \"!\"", t: "check" },
          { k: "hideUsers", label: "Hide messages from these users", t: "list", help: "One name per line, e.g. your bot accounts. Not case-sensitive." }
        ]},
        { title: "Layout", fields: [
          { k: "layout", label: "Layout", t: "select", opts: [["stack", "Vertical (messages stacked)"], ["line", "Horizontal (one line)"]] },
          { k: "newestAt", label: "Newest message at", t: "select", opts: [["bottom", "Bottom"], ["top", "Top"]], show: function (s) { return s.layout === "stack"; } },
          { k: "newestAt", label: "Newest message at", t: "select", opts: [["bottom", "Right"], ["top", "Left"]], show: function (s) { return s.layout === "line"; } },
          { k: "gap", label: "Space between messages", t: "range", min: 0, max: 40, step: 1, unit: "px" }
        ]},
        { title: "Names and icons", fields: [
          { k: "icons", label: "Platform icon", t: "select", opts: [["logo", "Platform's own site icon"], ["custom", "My own pictures"], ["dot", "Coloured dot"], ["none", "None"]] },
          { k: "iconUrls.kick", label: "Kick picture", t: "image", show: function (s) { return s.icons === "custom"; } },
          { k: "iconUrls.twitch", label: "Twitch picture", t: "image", show: function (s) { return s.icons === "custom"; } },
          { k: "iconUrls.youtube", label: "YouTube picture", t: "image", show: function (s) { return s.icons === "custom"; } },
          { k: "iconUrls.rumble", label: "Rumble picture", t: "image", show: function (s) { return s.icons === "custom"; } },
          { k: "nameColors", label: "Name colours", t: "select", opts: [["platform", "The colour each person picked on their platform"], ["single", "One colour for everyone"]] },
          { k: "nameColor", label: "Name colour", t: "color", show: function (s) { return s.nameColors === "single"; } },
          { k: "avatars", label: "Profile pictures", t: "check" },
          { k: "badges", label: "Badges", t: "check" },
          { k: "kickColor", label: "Kick colour (dots, and names without a colour)", t: "color" },
          { k: "twitchColor", label: "Twitch colour", t: "color" },
          { k: "youtubeColor", label: "YouTube colour", t: "color" },
          { k: "rumbleColor", label: "Rumble colour", t: "color" }
        ]},
        textSection("Message text", "text", { maxSize: 80 }),
        { title: "Bubbles", fields: [
          { k: "bubble", label: "Bubble colour", t: "color" },
          { k: "bubbleSee", label: "Bubble see-through", t: "range", min: 0, max: 100, step: 1, unit: "%" },
          { k: "radius", label: "Corner roundness", t: "range", min: 0, max: 30, step: 1, unit: "px" }
        ]}
      ]
    },

    music: {
      label: "Now Playing",
      blurb: "Shows the song that's playing, from AOverlay for Stream Music or from a text file.",
      box: { w: 900, h: 60, x: 30, y: 30 },
      defaults: {
        source: "aoverlay", aoverlayPort: 8095, filePath: "",
        showLabel: true, label: "Now Playing", icon: "\u266A",
        showSource: true, multiText: "{count} tracks open", hideWhenIdle: true, idleText: "Nothing playing",
        orientation: "horizontal", scroll: "auto", direction: "left", speed: 50,
        text: { font: "Segoe UI", size: 26, bold: true, shadow: true },
        labelColor: "#3ddc84",
        bgOn: true, bgColor: "#0e121a", bgSee: 15, radius: 10
      },
      form: [
        { title: "Where the song comes from", fields: [
          { k: "source", label: "Song source", t: "select", opts: [["aoverlay", "AOverlay for Stream Music"], ["file", "A text file"], ["off", "Off"]] },
          { k: "aoverlayPort", label: "AOverlay port", t: "number", min: 1, max: 65535, help: "Leave at 8095 unless you changed it in AOverlay's settings.", show: function (s) { return s.source === "aoverlay"; } },
          { k: "filePath", label: "Text file", t: "text", help: "Full path to a file your music program writes the current song into, e.g. C:\\Music\\nowplaying.txt", show: function (s) { return s.source === "file"; } }
        ]},
        { title: "Words", fields: [
          { k: "showLabel", label: "Show label", t: "check" },
          { k: "label", label: "Label", t: "text", show: function (s) { return s.showLabel; } },
          { k: "icon", label: "Icon", t: "text", help: "Any symbol or emoji, or leave empty." },
          { k: "labelColor", label: "Label and icon colour", t: "color" },
          { k: "showSource", label: "Show where it's playing (e.g. \"VLC:\")", t: "check" },
          { k: "multiText", label: "Text when several songs play", t: "text", help: "{count} becomes the number of songs." },
          { k: "hideWhenIdle", label: "Hide when nothing is playing", t: "check" },
          { k: "idleText", label: "Text when nothing is playing", t: "text", show: function (s) { return !s.hideWhenIdle; } }
        ]},
        { title: "Movement", fields: [
          { k: "orientation", label: "Layout", t: "select", opts: ORIENT, help: "Vertical runs the text top-to-bottom." },
          { k: "scroll", label: "Scrolling", t: "select", opts: [["auto", "Only when the text doesn't fit"], ["always", "Always"], ["never", "Never"]] },
          { k: "direction", label: "Scroll direction", t: "select", opts: DIR_H, show: function (s) { return s.scroll !== "never" && isH(s); } },
          { k: "direction", label: "Scroll direction", t: "select", opts: DIR_V, show: function (s) { return s.scroll !== "never" && !isH(s); } },
          { k: "speed", label: "Scroll speed", t: "range", min: 5, max: 300, step: 5, unit: "px/s", show: function (s) { return s.scroll !== "never"; } }
        ]},
        textSection("Text", "text"),
        { title: "Background", fields: bgFields("") }
      ]
    },

    emoteCombo: {
      label: "Emote Combo",
      blurb: "When chat repeats an emote, it shows the emote with a growing \"x3, x4...\" count.",
      box: { w: 360, h: 600, x: 1540, y: 120 },
      defaults: {
        platforms: { kick: true, twitch: true, youtube: true, rumble: true },
        minCount: 2, staySeconds: 6, maxRows: 10, stack: "up", emoteSize: 52, prefix: "x",
        hideUsers: "", listenToStreamerbot: true,
        text: { font: "Arial Black", size: 26, bold: true, color: "#53fc18", shadow: true, shadowDistance: 2.5, shadowFade: 4 },
        rowColor: "#000000", rowSee: 35, borderColor: "#53fc18", borderSee: 60, borderWidth: 2, radius: 12, gap: 8, pop: true
      },
      form: [
        { title: "Counting", fields: PLATFORM_FIELDS("platforms").concat([
          { k: "minCount", label: "Show once an emote has been used", t: "number", min: 1, max: 100, unit: "times" },
          { k: "staySeconds", label: "Remove a row after no repeats for", t: "number", min: 1, max: 120, step: 0.5, unit: "seconds" },
          { k: "maxRows", label: "Most rows at once", t: "number", min: 1, max: 50 },
          { k: "hideUsers", label: "Ignore emotes from these users", t: "list", help: "One name per line, e.g. bot accounts." },
          { k: "listenToStreamerbot", label: "Also count \"EmoteCount\" messages sent by a Streamer.bot action", t: "check" }
        ])},
        { title: "Layout", fields: [
          { k: "stack", label: "New rows appear", t: "select", opts: [["up", "Above the others (stacking up)"], ["down", "Below the others (stacking down)"], ["right", "Side by side, to the right"], ["left", "Side by side, to the left"]] },
          { k: "emoteSize", label: "Emote size", t: "range", min: 16, max: 200, step: 1, unit: "px" },
          { k: "prefix", label: "Before the number", t: "text" },
          { k: "pop", label: "Little pop when the count goes up", t: "check" },
          { k: "gap", label: "Space between rows", t: "range", min: 0, max: 40, step: 1, unit: "px" }
        ]},
        textSection("Count text", "text"),
        { title: "Row look", fields: [
          { k: "rowColor", label: "Row background", t: "color" },
          { k: "rowSee", label: "Row see-through", t: "range", min: 0, max: 100, step: 1, unit: "%" },
          { k: "borderColor", label: "Border colour", t: "color" },
          { k: "borderSee", label: "Border see-through", t: "range", min: 0, max: 100, step: 1, unit: "%" },
          { k: "borderWidth", label: "Border thickness", t: "range", min: 0, max: 10, step: 0.5, unit: "px" },
          { k: "radius", label: "Corner roundness", t: "range", min: 0, max: 40, step: 1, unit: "px" }
        ]}
      ]
    },

    emoteRain: {
      label: "Emote Rain",
      blurb: "Emotes from chat fall (or fly) across the area you draw.",
      box: { w: 1920, h: 1080, x: 0, y: 0 },
      defaults: {
        platforms: { kick: true, twitch: true, youtube: true, rumble: true },
        trigger: "every", comboMin: 3, perMessage: 3, maxOnScreen: 40,
        size: 112, sizeRandom: 0, seconds: 3.5, direction: "down", spin: false, wobble: false, fadeOut: true,
        hideUsers: "", listenToStreamerbot: true
      },
      form: [
        { title: "What makes it rain", fields: PLATFORM_FIELDS("platforms").concat([
          { k: "trigger", label: "Drop emotes", t: "select", opts: [["every", "Every emote used in chat"], ["combo", "Only when chat repeats an emote"]] },
          { k: "comboMin", label: "Repeats needed", t: "number", min: 2, max: 50, show: function (s) { return s.trigger === "combo"; } },
          { k: "perMessage", label: "Most emotes per message", t: "number", min: 1, max: 30 },
          { k: "maxOnScreen", label: "Most emotes on screen", t: "number", min: 1, max: 300 },
          { k: "hideUsers", label: "Ignore emotes from these users", t: "list" },
          { k: "listenToStreamerbot", label: "Also drop \"EmoteDrop\" messages sent by a Streamer.bot action", t: "check" }
        ])},
        { title: "Movement", fields: [
          { k: "direction", label: "Direction", t: "select", opts: [["down", "Fall down"], ["up", "Float up"], ["left", "Fly left"], ["right", "Fly right"]] },
          { k: "seconds", label: "Time to cross the area", t: "range", min: 0.5, max: 20, step: 0.1, unit: "seconds" },
          { k: "size", label: "Emote size", t: "range", min: 16, max: 300, step: 1, unit: "px" },
          { k: "sizeRandom", label: "Random size difference", t: "range", min: 0, max: 100, step: 1, unit: "%" },
          { k: "spin", label: "Spin", t: "check" },
          { k: "wobble", label: "Wobble side to side", t: "check" },
          { k: "fadeOut", label: "Fade out near the end", t: "check" }
        ]}
      ]
    },

    banner: {
      label: "Banner",
      blurb: "A graphic with text on it: pick a ready-made one or use your own picture.",
      box: { w: 700, h: 120, x: 610, y: 40 },
      defaults: {
        graphic: "plate", image: "", color1: "#6d28d9", color2: "#c084fc", graphicSee: 0, fit: "stretch",
        lines: "Welcome to the stream!", rotateSeconds: 8, motion: "fade", direction: "left", speed: 60,
        align: "center", padX: 40, padY: 10,
        text: { font: "Segoe UI", size: 40, bold: true, shadow: true }
      },
      form: [
        { title: "Graphic", fields: [
          { k: "graphic", label: "Graphic", t: "banner" },
          { k: "image", label: "Your picture", t: "image", show: function (s) { return s.graphic === "upload"; } },
          { k: "fit", label: "Fit the picture", t: "select", opts: [["stretch", "Stretch to the box"], ["contain", "Fit inside the box"], ["cover", "Fill the box (crop)"]], show: function (s) { return s.graphic === "upload"; } },
          { k: "color1", label: "Main colour", t: "color", show: function (s) { return s.graphic !== "upload" && s.graphic !== "none"; } },
          { k: "color2", label: "Second colour", t: "color", show: function (s) { return s.graphic !== "upload" && s.graphic !== "none"; } },
          { k: "graphicSee", label: "Graphic see-through", t: "range", min: 0, max: 100, step: 1, unit: "%", show: function (s) { return s.graphic !== "none"; } }
        ]},
        { title: "Words", fields: [
          { k: "lines", label: "Text", t: "list", help: "One message per line. With several lines, they take turns." },
          { k: "rotateSeconds", label: "Change message every", t: "number", min: 1, max: 600, unit: "seconds" },
          { k: "motion", label: "Movement", t: "select", opts: [["fade", "Fade between messages"], ["static", "Still"], ["scroll", "Scroll"]] },
          { k: "direction", label: "Scroll direction", t: "select", opts: DIR_H, show: function (s) { return s.motion === "scroll"; } },
          { k: "speed", label: "Scroll speed", t: "range", min: 5, max: 300, step: 5, unit: "px/s", show: function (s) { return s.motion === "scroll"; } },
          { k: "align", label: "Line up the text", t: "select", opts: [["left", "Left"], ["center", "Centre"], ["right", "Right"]], show: function (s) { return s.motion !== "scroll"; } },
          { k: "padX", label: "Space at the sides", t: "range", min: 0, max: 300, step: 1, unit: "px" },
          { k: "padY", label: "Space above and below", t: "range", min: 0, max: 200, step: 1, unit: "px" }
        ]},
        textSection("Text", "text", { maxSize: 200 })
      ]
    },

    web: {
      label: "Web widget",
      blurb: "Any overlay that has a link: Streamer.bot chat, Streamlabs, StreamElements, and others.",
      box: { w: 1920, h: 1080, x: 0, y: 0 },
      defaults: { kind: "link", url: "", zoom: 1, sbchat: null },
      form: []
    },

    file: {
      label: "Local file",
      blurb: "An HTML overlay page or picture saved on this computer.",
      box: { w: 800, h: 450, x: 560, y: 315 },
      defaults: { path: "", zoom: 1 },
      form: [
        { title: "File", fields: [
          { k: "path", label: "File", t: "text", help: "Full path, e.g. C:\\Overlays\\effect.html. Other files in the same folder (pictures, scripts) are available to it too." },
          { k: "zoom", label: "Size of the contents", t: "range", min: 0.2, max: 3, step: 0.05, pct: true }
        ]}
      ]
    }
  };

  /* ---------------- Ready-made web widgets ---------------- */
  var WEB_KINDS = {
    sbChat: {
      label: "Chat (Streamer.bot overlay)", blurb: "Streamer.bot's own chat overlay, set up from here.",
      box: { w: 520, h: 800, x: 30, y: 200 },
      hint: "Made for you from your Streamer.bot connection; no link needed.",
      match: /chat\.streamer\.bot\/overlay\/chat/i
    },
    streamlabs: {
      label: "Streamlabs widget", blurb: "Alert box, chat box, event list, goals, viewer count...",
      box: { w: 800, h: 600, x: 560, y: 240 },
      hint: "In your Streamlabs dashboard, open the widget and copy its widget URL. Change its look on Streamlabs' site.",
      match: /streamlabs\.com/i
    },
    streamelements: {
      label: "StreamElements overlay", blurb: "Any StreamElements overlay link.",
      box: { w: 1920, h: 1080, x: 0, y: 0 },
      hint: "In StreamElements, open the overlay and copy its link. Change its look on StreamElements' site.",
      match: /streamelements\.com/i
    },
    link: {
      label: "Other web link", blurb: "Any other overlay that gives you a link.",
      box: { w: 800, h: 450, x: 560, y: 315 },
      hint: "Paste the overlay's link."
    }
  };
  var SBCHAT_DEFAULTS = {
    fontSource: "google", fontFamily: "Inter", fontSize: 16, invert: false, showPlatformIcons: "multi",
    showPronouns: false, showAvatars: true, animateEmotes: true, min: 0, max: 20, timeout: 10,
    showEvents: true, showTimeStamps: false, layout: "inline", variant: "text",
    host: "127.0.0.1", port: 8080, endpoint: "/", password: "", secure: false
  };
  var SBCHAT_FORM = [
    { k: "fontFamily", label: "Font (Google Fonts name)", t: "text" },
    { k: "fontSize", label: "Text size", t: "number", min: 8, max: 72 },
    { k: "max", label: "Most messages on screen", t: "number", min: 1, max: 100 },
    { k: "timeout", label: "Messages disappear after (seconds, 0 = never)", t: "number", min: 0 },
    { k: "invert", label: "Newest at the top", t: "check" },
    { k: "showAvatars", label: "Profile pictures", t: "check" },
    { k: "showPronouns", label: "Pronouns", t: "check" },
    { k: "animateEmotes", label: "Animated emotes", t: "check" },
    { k: "showEvents", label: "Show events (subs, raids...)", t: "check" },
    { k: "showTimeStamps", label: "Time stamps", t: "check" },
    { k: "showPlatformIcons", label: "Platform icons", t: "select", opts: [["multi", "Only when several platforms"], ["always", "Always"], ["never", "Never"]] },
    { k: "layout", label: "Layout", t: "select", opts: [["inline", "Name and message on one line"], ["stacked", "Name above message"]] },
    { k: "variant", label: "Style", t: "select", opts: [["text", "Plain text"], ["bubble", "Bubbles"]] }
  ];
  function b64encodeUtf8(s) { return btoa(unescape(encodeURIComponent(s))); }
  function b64decodeUtf8(s) { return decodeURIComponent(escape(atob(s))); }
  function sbChatUrl(c) { return "https://chat.streamer.bot/overlay/chat?config=" + encodeURIComponent(b64encodeUtf8(JSON.stringify(c))); }
  function sbChatFromUrl(url) { try { var c = new URL(url).searchParams.get("config"); return c ? JSON.parse(b64decodeUtf8(c)) : null; } catch (e) { return null; } }
  function guessKind(url) {
    var keys = Object.keys(WEB_KINDS);
    for (var i = 0; i < keys.length; i++) { var k = WEB_KINDS[keys[i]]; if (k.match && k.match.test(url || "")) return keys[i]; }
    return "link";
  }

  /* =====================================================================
     Settings file
     ===================================================================== */
  function newId(p) { return (p || "o") + Date.now().toString(36) + Math.random().toString(36).slice(2, 6); }
  function newProfile(name) { return { id: newId("p"), name: name || "Main", overlays: [] }; }
  function defaultConfig() {
    return {
      schema: 2,
      canvas: { w: 1920, h: 1080 },
      streamerbot: { enabled: true, host: "127.0.0.1", port: 8080, endpoint: "/", password: "" },
      obs: { host: "127.0.0.1", port: 4455, password: "" },
      kick: { channel: "", chatroom: "" },
      rumble: { url: "", every: 5, liveChat: false },
      wizardDone: false,
      profiles: []
    };
  }
  function normalizeOverlay(o) {
    if (!o || !TYPES[o.type]) return null;
    // Botrix widgets were removed in 1.1: keep them as plain links so nothing disappears.
    if (o.type === "web" && o.settings && /^botrix/.test(o.settings.kind || "")) o.settings.kind = "link";
    o.settings = fillDefaults(o.settings || {}, TYPES[o.type].defaults);
    ["text"].forEach(function (k) { if (TYPES[o.type].defaults[k]) o.settings[k] = fillDefaults(o.settings[k], textStyle(TYPES[o.type].defaults[k])); });
    if (o.type === "web" && o.settings.kind === "sbChat") o.settings.sbchat = fillDefaults(o.settings.sbchat || {}, SBCHAT_DEFAULTS);
    if (typeof o.visible !== "boolean") o.visible = true;
    if (typeof o.opacity !== "number") o.opacity = 1;
    ["x", "y", "w", "h"].forEach(function (k) { o[k] = Math.round(Number(o[k]) || 0); });
    if (o.w < 10) o.w = 10; if (o.h < 10) o.h = 10;
    if (!o.id) o.id = newId();
    if (!o.name) o.name = TYPES[o.type].label;
    return o;
  }
  function normalizeConfig(cfg) {
    cfg = cfg && typeof cfg === "object" ? cfg : {};
    // Version 1 kept one list of overlays; it becomes the first profile.
    if (!Array.isArray(cfg.profiles)) {
      var p = newProfile("Main");
      p.overlays = Array.isArray(cfg.overlays) ? cfg.overlays : [];
      // keep using the scene and source that 1.0 made, so "Set up in OBS" doesn't make a second one
      if (cfg.obs) { p.obsScene = cfg.obs.sceneName || "AOverlay Hub"; p.obsSource = cfg.obs.sourceName || "AOverlay Hub Stage"; delete cfg.obs.sceneName; delete cfg.obs.sourceName; }
      cfg.profiles = [p];
      // Settings that moved from one overlay to the shared connections.
      p.overlays.forEach(function (o) {
        if (!o || !o.settings) return;
        if (o.type === "ticker" && o.settings.rumble && o.settings.rumble.url && !(cfg.rumble && cfg.rumble.url)) cfg.rumble = { url: o.settings.rumble.url, every: o.settings.rumble.every || 5 };
        if (o.type === "chat" && o.settings.kickChatroom && !(cfg.kick && cfg.kick.chatroom)) cfg.kick = { chatroom: String(o.settings.kickChatroom), channel: o.settings.kickChannel || "" };
        if (o.type === "chat" && o.settings.textColor) o.settings.text = { font: o.settings.font, size: o.settings.fontSize, color: o.settings.textColor, shadow: !!o.settings.outline };
        if (o.type === "chat" && typeof o.settings.bubbleOpacity === "number") o.settings.bubbleSee = Math.round((1 - o.settings.bubbleOpacity) * 100);
        if (o.type === "chat" && o.settings.kick === false) o.settings.sources = { kick: false, twitch: o.settings.streamerbot !== false, youtube: o.settings.streamerbot !== false, rumble: true };
        if (o.type === "music" && o.settings.textColor) { o.settings.text = { font: o.settings.font, size: o.settings.fontSize, color: o.settings.textColor, outline: !!o.settings.outline }; o.settings.bgColor = o.settings.panel; if (typeof o.settings.panelOpacity === "number") o.settings.bgSee = Math.round((1 - o.settings.panelOpacity) * 100); }
        if (o.type === "ticker" && o.settings.font) o.settings.text = { font: o.settings.font, size: o.settings.fontSize, bold: true, shadow: false };
      });
      delete cfg.overlays;
    }
    cfg = fillDefaults(cfg, defaultConfig());
    cfg.schema = 2;
    if (!cfg.profiles.length) cfg.profiles.push(newProfile("Main"));
    cfg.profiles.forEach(function (p, i) {
      if (!p.id) p.id = newId("p");
      if (!p.name) p.name = "Profile " + (i + 1);
      p.overlays = (Array.isArray(p.overlays) ? p.overlays : []).map(normalizeOverlay).filter(Boolean);
    });
    return cfg;
  }
  function profileById(cfg, id) {
    for (var i = 0; i < cfg.profiles.length; i++) if (cfg.profiles[i].id === id) return cfg.profiles[i];
    return cfg.profiles[0];
  }
  function obsNames(p) {
    return { scene: p.obsScene || ("AOverlay Hub - " + p.name), source: p.obsSource || ("AOverlay Hub Stage - " + p.name) };
  }
  function newOverlay(type, kind, canvas) {
    var t = TYPES[type];
    var box = clone((type === "web" && WEB_KINDS[kind || "link"]) ? WEB_KINDS[kind || "link"].box : t.box);
    var cw = (canvas && canvas.w) || 1920, ch = (canvas && canvas.h) || 1080;
    var sx = cw / 1920, sy = ch / 1080;
    var o = {
      id: newId(), type: type, visible: true, opacity: 1,
      x: Math.round(box.x * sx), y: Math.round(box.y * sy), w: Math.round(box.w * sx), h: Math.round(box.h * sy),
      name: type === "web" ? WEB_KINDS[kind || "link"].label : t.label,
      settings: clone(t.defaults)
    };
    if (type === "web") { o.settings.kind = kind || "link"; if (kind === "sbChat") o.settings.sbchat = clone(SBCHAT_DEFAULTS); }
    return normalizeOverlay(o);
  }
  function listOf(text) { return String(text || "").split(/\r?\n/).map(function (x) { return x.trim(); }).filter(Boolean); }

  root.AOH = {
    VERSION: VERSION, AUTHOR: "Aosabi 「青錆竜也」", CONTACT: "aosabi@pm.me", TYPES: TYPES, THEMES: THEMES, WEB_KINDS: WEB_KINDS, BANNERS: BANNERS, TEXT: TEXT,
    SBCHAT_DEFAULTS: SBCHAT_DEFAULTS, SBCHAT_FORM: SBCHAT_FORM,
    sbChatUrl: sbChatUrl, sbChatFromUrl: sbChatFromUrl, guessKind: guessKind,
    clone: clone, fillDefaults: fillDefaults, getPath: getPath, setPath: setPath,
    rgba: rgba, fontStack: fontStack, textStyle: textStyle, textFields: textFields, listOf: listOf,
    defaultConfig: defaultConfig, normalizeConfig: normalizeConfig, newOverlay: newOverlay, newId: newId,
    newProfile: newProfile, profileById: profileById, obsNames: obsNames
  };
})(window);
