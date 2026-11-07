// =====================================================================
//  AOverlay Hub - learn spam phrases from bans (Kick, Twitch, YouTube)
//  Copyright (c) 2026 Aosabi 「青錆竜也」 aosabi@pm.me. All Rights Reserved. See AOverlay Hub's LICENSE.txt.
//
//  When you or a mod bans someone, their last message is added to the spam phrase list in
//  AOverlay Hub (it shows up there straight away). Whether this is on, the shortest phrase it
//  will learn, and whether it says so in chat are set in AOverlay Hub > Moderation.
//  Mods can undo the newest one with !undophrase.
//
//  Triggers: Kick > User Banned, Twitch > User Banned, YouTube > User Banned
// =====================================================================
using System;
using System.IO;
using System.Net;
using System.Text;

public class CPHInline
{
    const string PORT = "{{HUB_PORT}}";
    const string HUB = "http://127.0.0.1:" + PORT;   // 127.0.0.1 answers at once when AOverlay Hub is closed ("localhost" can take seconds)

    public bool Execute()
    {
        try
        {
            string platform = Platform();
            string uid = Arg("userId");
            if (platform == "" || uid == "") return true;

            // bans made by the moderation action itself: that message is already on the list
            long flagged = CPH.GetGlobalVar<long>("aohFlag_" + platform + "_" + uid, false);
            if (flagged > 0 && (DateTime.UtcNow - new DateTime(flagged, DateTimeKind.Utc)).TotalMinutes < 5) return true;

            string last = CPH.GetGlobalVar<string>("aohLast_" + platform + "_" + uid, false);
            if (string.IsNullOrWhiteSpace(last)) return true;
            last = last.Replace("\r", " ").Replace("\n", " ").Trim();

            string r = Post("/api/mod/learn", "{\"text\":" + J(last) + ",\"user\":" + J(Arg("userName")) + ",\"platform\":" + J(platform) + "}");
            CPH.SetGlobalVar("aohLast_" + platform + "_" + uid, "", false);
            if (r != null && r.Contains("\"announce\":true"))
                Reply(platform, "Banned message added to the spam phrase list. Mods can undo it with !undophrase");
        }
        catch (Exception ex) { CPH.LogError("[AOverlay Hub learn] " + ex.Message); }
        return true;
    }

    void Reply(string platform, string text)
    {
        try
        {
            if (platform == "kick") CPH.SendKickMessage(text, true);
            else if (platform == "twitch") CPH.SendMessage(text, true);
            else if (platform == "youtube") CPH.SendYouTubeMessage(text, true, true, null);
        }
        catch { }
    }

    string Platform()
    {
        string s = "";
        try { s = CPH.GetSource().ToString().ToLowerInvariant(); } catch { }
        if (s.Contains("kick")) return "kick";
        if (s.Contains("twitch")) return "twitch";
        if (s.Contains("youtube")) return "youtube";
        string src = Arg("__source").ToLowerInvariant();
        if (src.StartsWith("kick")) return "kick";
        if (src.StartsWith("twitch")) return "twitch";
        if (src.StartsWith("youtube")) return "youtube";
        return "";
    }

    string Arg(string key) { object v; return args != null && args.TryGetValue(key, out v) && v != null ? v.ToString() : ""; }

    static string J(string s)
    {
        if (s == null) return "null";
        var sb = new StringBuilder("\"");
        foreach (char c in s)
        {
            if (c == '"') sb.Append("\\\""); else if (c == '\\') sb.Append("\\\\");
            else if (c < ' ') sb.Append("\\u" + ((int)c).ToString("x4"));
            else sb.Append(c);
        }
        return sb.Append('"').ToString();
    }

    static string Post(string path, string json)
    {
        try
        {
            var r = (HttpWebRequest)WebRequest.Create(HUB + path);
            r.Host = "localhost:" + PORT;   // AOverlay Hub only answers to "localhost"
            r.Method = "POST"; r.Timeout = 1500; r.ReadWriteTimeout = 1500; r.Proxy = null;
            r.Headers["X-AOH"] = "1"; r.ContentType = "application/json";
            byte[] b = Encoding.UTF8.GetBytes(json); r.ContentLength = b.Length;
            using (Stream s = r.GetRequestStream()) s.Write(b, 0, b.Length);
            using (var resp = (HttpWebResponse)r.GetResponse())
            using (var sr = new StreamReader(resp.GetResponseStream(), Encoding.UTF8)) return sr.ReadToEnd();
        }
        catch { return null; }
    }
}
