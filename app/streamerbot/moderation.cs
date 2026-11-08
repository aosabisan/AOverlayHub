// =====================================================================
//  AOverlay Hub - spam phrase moderation (Kick, Twitch, YouTube)
//  Copyright (c) 2026 Aosabi 「青錆竜也」 aosabi@pm.me. All Rights Reserved. See AOverlay Hub's LICENSE.txt.
//
//  Deletes the message and times out (or bans) anyone who says a blocked phrase.
//  Matching ignores capital letters, punctuation and extra spaces.
//  The streamer, moderators (optional), VIPs (optional) and trusted chatters are never acted on.
//  The phrase list and every setting are managed in AOverlay Hub > Moderation; this action reads
//  them from AOverlay Hub every 5 seconds and keeps working with the last copy if it's closed.
//
//  Triggers: Kick > Chat Message, Twitch > Chat Message, YouTube > Message
// =====================================================================
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;

public class CPHInline
{
    const string PORT = "{{HUB_PORT}}";
    const string HUB = "http://127.0.0.1:" + PORT;   // 127.0.0.1 answers at once when AOverlay Hub is closed ("localhost" can take seconds)
    static DateTime hubDownUntil = DateTime.MinValue;
    static DateTime fetchedAt = DateTime.MinValue;
    static Dictionary<string, string> S = null;
    static List<string> P = new List<string>();
    static bool badgeLogged = false;

    public bool Execute()
    {
        try { Run(); }
        catch (Exception ex) { CPH.LogError("[AOverlay Hub moderation] " + ex.Message); }
        return true;
    }

    void Run()
    {
        if (Arg("isInternal").Equals("true", StringComparison.OrdinalIgnoreCase)) return;
        string platform = Platform();
        if (platform == "") return;
        Load();
        ImportOldList();
        if (S == null || Get("enabled") != "1" || Get(platform) != "1") return;

        string uid = Arg("userId");
        string message = Arg("message");
        TrackMessage(platform, uid, message);   // so a ban can learn a new chatter's first message
        if (HandleCommand(platform, message)) return;

        string msg = Normalize(message);
        if (msg == "") return;
        string hit = P.FirstOrDefault(p => p != "" && msg.Contains(p));
        if (hit == null) { CountClean(platform, uid); return; }

        if (IsOwner(platform)) return;
        if (Get("exemptMods") == "1" && IsTrue("isModerator")) return;
        if (IsTrusted(platform, uid)) return;

        CPH.SetGlobalVar("aohFlag_" + platform + "_" + uid, DateTime.UtcNow.Ticks, false);
        string login = Arg("userName");
        string msgId = platform == "twitch" ? First(Arg("msgId"), Arg("messageId")) : First(Arg("messageId"), Arg("msgId"), Arg("eventId"));
        if (Get("delete") == "1" && msgId != "")
        {
            if (platform == "kick") CPH.KickDeleteChatMessage(msgId);
            else if (platform == "twitch") CPH.TwitchDeleteChatMessage(msgId, false);
        }
        bool ban = Get("action") == "ban";
        int secs = ToInt(Get("timeout"), 600);
        string reason = Get("reason"); if (reason == "") reason = "Spam message";
        string bid = Arg("broadcastId"); if (bid == "") bid = null;
        bool ok = false;
        if (platform == "kick") ok = ban ? CPH.KickBanUser(login, reason) : CPH.KickTimeoutUser(login, secs, reason);
        else if (platform == "twitch") ok = ban ? CPH.TwitchBanUser(login, reason) : CPH.TwitchTimeoutUser(login, secs, reason);
        else if (platform == "youtube") ok = ban ? CPH.YouTubeBanUserById(uid, bid) : CPH.YouTubeTimeoutUserById(uid, secs, bid);
        CPH.LogInfo("[AOverlay Hub moderation] " + platform + " " + login + (ok ? (ban ? " banned" : " timed out") : " - FAILED (does the account have mod rights?)"));
        Post("/api/mod/log", "{\"platform\":" + J(platform) + ",\"user\":" + J(login) + ",\"action\":" + J(ban ? "ban" : "timeout") +
             ",\"phrase\":" + J(hit) + ",\"message\":" + J(message) + ",\"ok\":" + (ok ? "true" : "false") + "}");
    }

    // ---------------- settings and phrases from AOverlay Hub ----------------
    void Load()
    {
        if (S != null && (DateTime.UtcNow - fetchedAt).TotalSeconds < 5) return;   // changes made in AOverlay Hub arrive within 5 seconds
        fetchedAt = DateTime.UtcNow;
        try
        {
            string t = Http("GET", HUB + "/api/mod/sb", null);
            if (t.StartsWith("aoh-mod")) { Parse(t); CPH.SetGlobalVar("aohModCache", t, true); return; }
        }
        catch { }
        if (S == null)
        {
            string c = CPH.GetGlobalVar<string>("aohModCache", true);
            if (!string.IsNullOrEmpty(c)) Parse(c);
        }
    }

    void Parse(string t)
    {
        var s = new Dictionary<string, string>();
        var p = new List<string>();
        bool phrases = false;
        foreach (string raw in t.Replace("\r", "").Split('\n'))
        {
            if (raw == "---") { phrases = true; continue; }
            if (phrases) { string n = raw.Trim(); if (n != "") p.Add(n); continue; }
            int i = raw.IndexOf('=');
            if (i > 0) s[raw.Substring(0, i)] = raw.Substring(i + 1);
        }
        S = s; P = p;
    }

    string Get(string key) { string v; return S != null && S.TryGetValue(key, out v) ? v : ""; }

    // Brings over a list kept by an older script in the global variable "learnedPhrases" (once).
    void ImportOldList()
    {
        if (S == null || CPH.GetGlobalVar<bool>("aohImportedOldList", true)) return;
        string old = CPH.GetGlobalVar<string>("learnedPhrases", true) ?? "";
        var list = old.Split('\n').Select(x => x.Trim()).Where(x => x != "").ToList();
        if (list.Count > 0)
        {
            string r = Post("/api/mod/op", "{\"op\":\"import\",\"phrases\":[" + string.Join(",", list.Select(J)) + "]}");
            if (r == null || !r.Contains("\"ok\":true")) return;   // try again next time
        }
        CPH.SetGlobalVar("aohImportedOldList", true, true);
    }

    // Counts every chat message per person, and keeps the FIRST one while they have sent fewer than
    // "learnMaxMessages" (default 4). If someone like that is banned, learn.cs adds that first message
    // to the spam list. Past the limit the stored message is thrown away, so regulars cost nothing.
    void TrackMessage(string platform, string uid, string message)
    {
        if (uid == "") return;
        int max = ToInt(Get("learnMaxMessages"), 4);
        string ck = "aohCount_" + platform + "_" + uid, fk = "aohFirst_" + platform + "_" + uid;
        int c = CPH.GetGlobalVar<int>(ck, true);
        if (c >= max) return;
        if (c == 0)
        {
            string first = (message ?? "").Replace("\r", " ").Replace("\n", " ").Trim();
            if (first.Length > 300) first = first.Substring(0, 300);
            CPH.SetGlobalVar(fk, first, true);
        }
        CPH.SetGlobalVar(ck, c + 1, true);
        if (c + 1 >= max) CPH.UnsetGlobalVar(fk, true);
    }

    // ---------------- chat commands for the streamer and mods ----------------
    // The words are set in AOverlay Hub > Moderation. AOverlay Hub is always sent the standard name.
    string Word(string key, string def) { string w = Get(key); return w == "" ? def : w.ToLowerInvariant(); }

    bool HandleCommand(string platform, string message)
    {
        string m = (message ?? "").Trim();
        if (m.Length < 2) return false;
        string[] parts = m.Split(new[] { ' ' }, 2);
        string word = parts[0].ToLowerInvariant();
        string cmd = "";
        if (word == Word("cmdMode", "!phrasemode")) cmd = "!phrasemode";
        else if (word == Word("cmdAdd", "!addphrase")) cmd = "!addphrase";
        else if (word == Word("cmdDel", "!delphrase")) cmd = "!delphrase";
        else if (word == Word("cmdUndo", "!undophrase")) cmd = "!undophrase";
        if (cmd == "") return false;
        if (Get("commands") != "1") return true;
        if (!IsOwner(platform) && !IsTrue("isModerator")) return true;   // viewers can't use these
        string rest = parts.Length > 1 ? parts[1].Trim() : "";
        string r = Post("/api/mod/cmd", "{\"cmd\":" + J(cmd) + ",\"text\":" + J(rest) + ",\"by\":" + J(Arg("userName")) + ",\"platform\":" + J(platform) + "}");
        fetchedAt = DateTime.MinValue;   // pick up the change straight away
        string reply = ReadString(r, "reply");
        if (reply != "") Reply(platform, reply);
        return true;
    }

    void Reply(string platform, string text)
    {
        try
        {
            if (platform == "kick") CPH.SendKickMessage(text, true);
            else if (platform == "twitch") CPH.SendMessage(text, true);
            else if (platform == "youtube") { string b = Arg("broadcastId"); CPH.SendYouTubeMessage(text, true, true, b == "" ? null : b); }
        }
        catch { }
    }

    // ---------------- who is safe ----------------
    bool IsOwner(string platform)
    {
        if (platform == "youtube") return IsTrue("isOwner");
        string bid = Arg("broadcastUserId"), bname = Arg("broadcastUserName");
        if (bid != "" && bid == Arg("userId")) return true;
        return bname != "" && bname.Equals(Arg("userName"), StringComparison.OrdinalIgnoreCase);
    }

    void CountClean(string platform, string uid)
    {
        int after = ToInt(Get("trustedAfter"), 4);
        if (uid == "" || after <= 0) return;
        string key = "aohClean_" + platform + "_" + uid;
        int c = CPH.GetGlobalVar<int>(key, true);
        if (c <= after) CPH.SetGlobalVar(key, c + 1, true);
    }

    bool IsTrusted(string platform, string uid)
    {
        int after = ToInt(Get("trustedAfter"), 4);
        if (after > 0 && uid != "" && CPH.GetGlobalVar<int>("aohClean_" + platform + "_" + uid, true) > after) return true;
        if (Get("exemptVip") != "1") return false;
        if (IsTrue("isVip")) return true;
        if (platform != "kick") return false;
        try
        {
            object b = args.ContainsKey("badge") ? args["badge"] : (args.ContainsKey("badges") ? args["badges"] : null);
            var list = b as System.Collections.IEnumerable;
            if (list == null || b is string) return false;
            foreach (object item in list)
            {
                if (item == null) continue;
                var parts = item.GetType().GetProperties().Select(p => { try { return Convert.ToString(p.GetValue(item, null)); } catch { return ""; } });
                string s = (item.ToString() + " " + string.Join(" ", parts)).ToLowerInvariant();
                if (!badgeLogged) { badgeLogged = true; CPH.LogInfo("[AOverlay Hub moderation] sample badge data: " + s); }
                if (System.Text.RegularExpressions.Regex.IsMatch(s, @"\b(vip|og)\b")) return true;
            }
        }
        catch { }
        return false;
    }

    // ---------------- small helpers ----------------
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

    static string Normalize(string s)
    {
        if (string.IsNullOrEmpty(s)) return "";
        var sb = new StringBuilder();
        bool space = false;
        foreach (char c in s.ToLowerInvariant())
        {
            if (char.IsLetterOrDigit(c)) { sb.Append(c); space = false; }
            else if (!space && sb.Length > 0) { sb.Append(' '); space = true; }
        }
        return sb.ToString().Trim();
    }

    string Arg(string key) { object v; return args != null && args.TryGetValue(key, out v) && v != null ? v.ToString() : ""; }
    bool IsTrue(string key) { return Arg(key).Equals("true", StringComparison.OrdinalIgnoreCase); }
    static string First(params string[] v) { foreach (string x in v) if (!string.IsNullOrEmpty(x)) return x; return ""; }
    static int ToInt(string s, int d) { int n; return int.TryParse(s, out n) ? n : d; }

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

    static string Http(string method, string url, string body)
    {
        if (DateTime.UtcNow < hubDownUntil) throw new WebException("AOverlay Hub was not running a moment ago");
        var r = (HttpWebRequest)WebRequest.Create(url);
        r.Host = "localhost:" + PORT;   // AOverlay Hub only answers to "localhost"
        r.Method = method; r.Timeout = 1500; r.ReadWriteTimeout = 1500; r.Proxy = null;
        r.Headers["X-AOH"] = "1";
        try
        {
            if (body != null)
            {
                byte[] b = Encoding.UTF8.GetBytes(body);
                r.ContentType = "application/json"; r.ContentLength = b.Length;
                using (Stream s = r.GetRequestStream()) s.Write(b, 0, b.Length);
            }
        }
        catch (WebException) { hubDownUntil = DateTime.UtcNow.AddSeconds(30); throw; }
        try
        {
            using (var resp = (HttpWebResponse)r.GetResponse())
            using (var sr = new StreamReader(resp.GetResponseStream(), Encoding.UTF8)) return sr.ReadToEnd();
        }
        catch (WebException ex)
        {
            // not running: don't slow every chat message down by trying again straight away
            if (ex.Response == null) hubDownUntil = DateTime.UtcNow.AddSeconds(30);
            throw;
        }
    }

    static string Post(string path, string json) { try { return Http("POST", HUB + path, json); } catch { return null; } }
}
