// =====================================================================
//  AOverlay Hub - learn spam phrases from bans (Kick, Twitch, YouTube)
//  Copyright (c) 2026 Aosabi 「青錆竜也」 aosabi@pm.me. All Rights Reserved. See AOverlay Hub's LICENSE.txt.
//
//  When you or a mod bans someone who had sent fewer than 4 chat messages in total (a typical spam
//  bot), their FIRST message is added to the spam phrase list in AOverlay Hub (it shows up there
//  straight away). The message limit, the shortest phrase it will learn, whether it says so in
//  chat and what it says are set in AOverlay Hub > Moderation. The moderation action keeps the
//  message count and the first message. Mods can undo the newest one with the undo command
//  (!undophrase unless you changed it).
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

            // the first message and the number of messages are kept by the moderation action
            string fk = "aohFirst_" + platform + "_" + uid;
            string first = CPH.GetGlobalVar<string>(fk, true);
            if (string.IsNullOrWhiteSpace(first)) return true;   // not seen as a new chatter: nothing to learn
            first = first.Replace("\r", " ").Replace("\n", " ").Trim();
            int count = CPH.GetGlobalVar<int>("aohCount_" + platform + "_" + uid, true);

            // AOverlay Hub applies the rule (fewer than the set number of messages) and the settings
            string r = Post("/api/mod/learn", "{\"text\":" + J(first) + ",\"user\":" + J(Arg("userName")) + ",\"platform\":" + J(platform) + ",\"count\":" + count + "}");
            CPH.UnsetGlobalVar(fk, true);
            string say = ReadString(r, "say");
            if (say != "") Reply(platform, say);
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

    static string ReadString(string json, string key)
    {
        if (string.IsNullOrEmpty(json)) return "";
        var m = System.Text.RegularExpressions.Regex.Match(json, "\"" + key + "\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"");
        return m.Success ? System.Text.RegularExpressions.Regex.Unescape(m.Groups[1].Value) : "";
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
