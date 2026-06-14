# kbs renderer. Reads a section-marked keybinding dump on stdin, classifies each
# binding via rules.dat, and emits either rows (key|source|action) or a table.
# POSIX awk (no gawk extensions). See kbs.bash for how the dump is produced.

function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

function strip_quotes(s,   sl) {
  sl = length(s)
  if (sl < 2) return s
  if ((substr(s,1,1)=="'" && substr(s,sl,1)=="'") || \
      (substr(s,1,1)=="\"" && substr(s,sl,1)=="\"")) return (sl > 2) ? substr(s, 2, sl - 2) : ""
  return s
}

function load_rules(f,   line, _n, _a, k) {
  while ((getline line < f) > 0) {
    if (line ~ /^[ \t]*#/ || line ~ /^[ \t]*$/) continue
    _n = split(line, _a, /\|/)
    for (k = 1; k <= _n; k++) _a[k] = trim(_a[k])
    if (_a[1] == "rule") {
      rn++
      rtype[rn]=_a[2]; rkey[rn]=_a[3]; rtarget[rn]=_a[4]; rmacro[rn]=_a[5]; rsrc[rn]=_a[6]; ract[rn]=_a[7]
    } else if (_a[1] == "bykey") {
      if (!((_a[2], _a[3]) in bykey)) bykey[_a[2], _a[3]] = _a[4]
    } else if (_a[1] == "synth") {
      sn++; s_src[sn]=_a[2]; s_key[sn]=_a[3]; s_act[sn]=_a[4]
    } else if (_a[1] == "builtin") {
      if (!(_a[2] in binact)) { binact[_a[2]] = _a[3]; bis[_a[2]] = 1 }
    } else if (_a[1] == "example") {
      en++; e_src[en]=_a[2]; e_text[en]=_a[3]
    }
  }
  close(f)
}

function arrow(c) { return ARROW[c] }

function canon(k,   lk, _n) {
  k = trim(k)
  k = strip_quotes(k)
  if (k == "") return ""
  if (index(k, "C-_") > 0) return ""                       # internal dispatch keys
  if (k ~ /^\\e(\[|O)[A-H]$/) return arrow(substr(k, length(k), 1))
  if (k ~ /^\\e\[[0-9]+~$/) { _n=k; gsub(/[^0-9]/, "", _n); return (_n in TILDE) ? TILDE[_n] : "" }
  if (k=="\\t" || k=="\\C-i" || k=="C-i" || k=="TAB") return "Tab"
  if (k=="\\r" || k=="\\C-m" || k=="C-m" || k=="RET") return "Enter"
  if (k ~ /^\\C-.$/) return "Ctrl-" toupper(substr(k, length(k), 1))
  if (k ~ /^\\e.$/)  return "Alt-"  toupper(substr(k, length(k), 1))
  if (k ~ /^(SS3|CSI|ESC \[|ESC O) [A-H]$/) return arrow(substr(k, length(k), 1))
  lk = tolower(k)
  if (lk in NAMED) return NAMED[lk]
  if (k ~ /^C-.$/) return "Ctrl-" toupper(substr(k, 3, 1))
  if (k ~ /^M-.$/) return "Alt-"  toupper(substr(k, 3, 1))
  # backslash-escaped modified keys, e.g. ble's M-\' (Alt-') or C-\' (Ctrl-')
  if (k ~ /^C-\\.$/) return "Ctrl-" toupper(substr(k, length(k), 1))
  if (k ~ /^M-\\.$/) return "Alt-"  toupper(substr(k, length(k), 1))
  if (index(k, " ") > 0) return ""                          # multi-token compound
  return k
}

# Parse a ble-bind line into P_km, P_type, P_key, P_target; sets P_ok.
function parse_ble(line,   rest, p, q, _ty) {
  P_ok = 0
  if (substr(line, 1, 13) != "ble-bind -m '") return
  rest = substr(line, 14)
  p = index(rest, "'"); if (!p) return
  P_km = substr(rest, 1, p-1)
  rest = substr(rest, p+1)                 # " -s C-r '...'"
  if (substr(rest, 1, 2) != " -") return
  _ty = substr(rest, 3, 1)
  if (_ty != "f" && _ty != "c" && _ty != "s" && _ty != "x") return
  rest = substr(rest, 4)                   # " C-r '...'"
  sub(/^[ \t]+/, "", rest)
  if (substr(rest, 1, 1) == "'") {
    rest = substr(rest, 2); q = index(rest, "'")
    P_key = substr(rest, 1, q-1); rest = substr(rest, q+1)
  } else {
    q = index(rest, " ")
    if (q) { P_key = substr(rest, 1, q-1); rest = substr(rest, q+1) }
    else   { P_key = rest; rest = "" }
  }
  # ble escapes an embedded single-quote in a key as '...'\''...': after the first
  # closing quote the leftover begins with \' — meaning the key is a compound chord
  # (e.g. "C-x '") we don't represent. Drop it rather than emit a mangled key.
  if (rest ~ /^\\'/) return
  P_type = _ty; P_target = strip_quotes(trim(rest)); P_ok = 1
}

# Parse a readline line for section flag (-p/-s/-X) into P_key(seq)/P_type/P_target.
function parse_readline(line, flag,   rest, q) {
  P_ok = 0
  if (substr(line, 1, 1) != "\"") return
  rest = substr(line, 2); q = index(rest, "\""); if (!q) return
  P_key = (q > 1) ? substr(rest, 1, q-1) : ""; rest = substr(rest, q+1)
  if (flag == "-X") {
    sub(/^[ \t]+/, "", rest)
    if (substr(rest, 1, 1) == "\"") { rest = substr(rest, 2); q = index(rest, "\""); rest = (q > 1) ? substr(rest, 1, q-1) : (q == 1 ? "" : rest) }
    P_type = "x"; P_target = rest
  } else {
    sub(/^:[ \t]*/, "", rest)
    if (substr(rest, 1, 1) == "\"") { rest = substr(rest, 2); q = index(rest, "\""); rest = (q > 1) ? substr(rest, 1, q-1) : (q == 1 ? "" : rest) }
    P_type = (flag == "-s") ? "s" : "f"; P_target = rest
  }
  P_km = "readline"; P_ok = 1
}

function classify(_km, _ty, _key, _tgt,   _i) {
  for (_i = 1; _i <= rn; _i++) {
    if (rtype[_i] != "" && rtype[_i] != "*" && rtype[_i] != _ty) continue
    if (rkey[_i]  != "" && rkey[_i]  != "*" && rkey[_i]  != _key) continue
    if (rtarget[_i] != "" && rtarget[_i] != "*" && index(_tgt, rtarget[_i]) == 0) continue
    if (rmacro[_i]  != "" && rmacro[_i]  != "*" && index(_tgt, rmacro[_i])  == 0) continue
    CL_src = rsrc[_i]
    CL_act = ract[_i]
    if (CL_act == "@bykey") CL_act = ((CL_src, _key) in bykey) ? bykey[CL_src, _key] : _tgt
    if (CL_act == "") CL_act = _tgt
    return
  }
  if (index(_tgt, "fzf")   > 0) { CL_src="fzf";    CL_act=_tgt; return }
  if (index(_tgt, "atuin") > 0) { CL_src="atuin";  CL_act=_tgt; return }
  if (_km == "readline" && _ty == "f") { CL_src="readline"; CL_act=_tgt; return }
  if (_tgt != "") { CL_src="ble.sh"; CL_act=_tgt; return }
  CL_src="other"; CL_act="(internal)"
}

BEGIN {
  rn = 0; sn = 0; en = 0; Wn = 0   # accumulator counts (explicit init keeps gawk --lint quiet)
  ARROW["A"]="Up"; ARROW["B"]="Down"; ARROW["C"]="Right"; ARROW["D"]="Left"; ARROW["F"]="End"; ARROW["H"]="Home"
  TILDE["1"]="Home"; TILDE["2"]="Insert"; TILDE["3"]="Delete"; TILDE["4"]="End"; TILDE["5"]="PageUp"; TILDE["6"]="PageDown"
  NAMED["up"]="Up"; NAMED["down"]="Down"; NAMED["left"]="Left"; NAMED["right"]="Right"
  NAMED["home"]="Home"; NAMED["end"]="End"; NAMED["insert"]="Insert"; NAMED["delete"]="Delete"
  NAMED["prior"]="PageUp"; NAMED["next"]="PageDown"; NAMED["tab"]="Tab"
  NAMED["nul"]="Ctrl-@"; NAMED["bs"]="Backspace"; NAMED["del"]="Backspace"
  NAMED["sp"]="Space"; NAMED["esc"]="Escape"; NAMED["ret"]="Enter"
  RANK["s"]=0; RANK["x"]=1; RANK["c"]=2; RANK["f"]=3
  ORD["atuin"]=1; ORD["fzf"]=2; ORD["ble.sh"]=3; ORD["readline"]=4; ORD["shell"]=5; ORD["other"]=6
  COLOR["atuin"]="\033[38;5;213m"; COLOR["fzf"]="\033[38;5;114m"
  COLOR["ble.sh"]="\033[38;5;75m"; COLOR["readline"]="\033[38;5;179m"
  COLOR["shell"]="\033[38;5;245m"; COLOR["other"]="\033[38;5;245m"
  if (userrules != "") load_rules(userrules)
  load_rules(rules)
  KMFILTER = (backend == "readline") ? "readline" : keymap
}

/^## / {
  n = split(substr($0, 4), a, /[ \t]+/)
  if (a[1] == "ble")      { SEC=1; SKIND="ble" }
  else if (a[1] == "readline") { SEC=1; SKIND="readline"; SFLAG=(n>=2?a[2]:"-p") }
  else SEC=0
  next
}
/^[ \t]*$/ { next }
{
  if (!SEC) next
  if (SKIND == "ble") { parse_ble($0); if (!P_ok) next }
  else                { parse_readline($0, SFLAG); if (!P_ok) next }
  key = canon(P_key)
  if (key == "" || P_target == "") next
  if (P_km != KMFILTER) next
  g = P_km SUBSEP key
  r = RANK[P_type]
  if (!(g in Wrank)) { Worder[++Wn] = g; Wrank[g]=r; Wty[g]=P_type; Wtg[g]=P_target; Wkm[g]=P_km; Wkey[g]=key }
  else if (r < Wrank[g]) { Wrank[g]=r; Wty[g]=P_type; Wtg[g]=P_target; Wkm[g]=P_km; Wkey[g]=key }
}

END {
  nr = 0
  for (i = 1; i <= Wn; i++) {
    g = Worder[i]; ty = Wty[g]; key = Wkey[g]; km = Wkm[g]; tgt = Wtg[g]
    nd = (ty == "s" || ty == "x" || ty == "c")
    bi = (key in bis)
    if (level == "A" && !nd) continue
    if (level == "B" && !(nd || bi)) continue
    classify(km, ty, key, tgt)
    src = CL_src; act = CL_act
    if (!nd && (key in binact)) act = binact[key]
    nr++; rk[nr]=key; rs[nr]=src; ra[nr]=act
  }
  # insertion sort by (ORD[source], key)
  for (i = 2; i <= nr; i++) {
    kk=rk[i]; ss=rs[i]; aa=ra[i]; oi=(rs[i] in ORD)?ORD[rs[i]]:99
    j = i - 1
    while (j >= 1 && ( (rs[j] in ORD ? ORD[rs[j]] : 99) > oi || ((rs[j] in ORD ? ORD[rs[j]] : 99) == oi && rk[j] > kk) )) {
      rk[j+1]=rk[j]; rs[j+1]=rs[j]; ra[j+1]=ra[j]; j--
    }
    rk[j+1]=kk; rs[j+1]=ss; ra[j+1]=aa
  }
  # synthetic rows
  nsy = 0
  for (i = 1; i <= sn; i++) { sk = s_key[i]; gsub(/\{trigger\}/, trigger, sk); nsy++; yk[nsy]=sk; ys[nsy]=s_src[i]; ya[nsy]=s_act[i] }
  # final order: synthetic first (A/B), last (C)
  nf = 0
  if (level != "C") for (i=1;i<=nsy;i++){ nf++; fk[nf]=yk[i]; fs[nf]=ys[i]; fa[nf]=ya[i] }
  for (i=1;i<=nr;i++){ nf++; fk[nf]=rk[i]; fs[nf]=rs[i]; fa[nf]=ra[i] }
  if (level == "C") for (i=1;i<=nsy;i++){ nf++; fk[nf]=yk[i]; fs[nf]=ys[i]; fa[nf]=ya[i] }

  if (emit == "rows") { for (i=1;i<=nf;i++) print fk[i] "|" fs[i] "|" fa[i]; exit (nf>0?0:1) }
  if (nf == 0) { print "kbs: no bindings found (no interactive keymap could be read)." > "/dev/stderr"; exit 1 }
  render_table()
  if (examples == 1) render_examples()
}

# --- rendering ---
function rep(_n, ch,   s) { s=""; while (_n-- > 0) s = s ch; return s }
function pad(s, w) { return s rep(w - length(s), " ") }

function render_table(   _i, kw, sw, aw, total, B, R, sc, title, lvltext, tl) {
  B = (color == 1) ? "\033[1m" : ""
  R = (color == 1) ? "\033[0m" : ""
  # The default (level A) view nudges toward the more-verbose levels.
  lvltext = (level == "A") ? "use -v or -vv for more bindings" : ("level " level)
  title = "Keybindings - " lvltext
  kw = length("Key"); sw = length("Source"); aw = length("Action")
  for (_i = 1; _i <= nf; _i++) {
    if (length(fk[_i]) > kw) kw = length(fk[_i])
    if (length(fs[_i]) > sw) sw = length(fs[_i])
    if (length(fa[_i]) > aw) aw = length(fa[_i])
  }
  total = kw + sw + aw + 8
  # Ensure the title fits: if it's wider than the columns, widen the action column
  # (keeps the 3-column divider alignment and the box width-correct).
  tl = length(title)
  if (tl + 2 > total) { aw += tl + 2 - total; total = kw + sw + aw + 8 }
  print ""
  print "┌" rep(total, "─") "┐"
  print "│ " B pad(title, total - 2) R " │"
  print "├" rep(kw+2,"─") "┬" rep(sw+2,"─") "┬" rep(aw+2,"─") "┤"
  print "│ " B pad("Key", kw) R " │ " B pad("Source", sw) R " │ " B pad("Action", aw) R " │"
  print "├" rep(kw+2,"─") "┼" rep(sw+2,"─") "┼" rep(aw+2,"─") "┤"
  for (_i = 1; _i <= nf; _i++) {
    sc = (color == 1 && (fs[_i] in COLOR)) ? COLOR[fs[_i]] : ""
    print "│ " B pad(fk[_i], kw) R " │ " sc pad(fs[_i], sw) R " │ " pad(fa[_i], aw) " │"
  }
  print "└" rep(kw+2,"─") "┴" rep(sw+2,"─") "┴" rep(aw+2,"─") "┘"
}
function render_examples(   _i, DIM, B, R, present, has) {
  DIM = (color == 1) ? "\033[2m" : ""
  B   = (color == 1) ? "\033[1m" : ""
  R   = (color == 1) ? "\033[0m" : ""
  for (_i = 1; _i <= nf; _i++) present[fs[_i]] = 1
  has = 0
  for (_i = 1; _i <= en; _i++) if (e_src[_i] in present) { has = 1; break }
  if (!has) return
  print ""
  print B "Examples" R DIM "  - fzf " trigger " trigger: type " trigger " where you'd hit Tab" R
  for (_i = 1; _i <= en; _i++) if (e_src[_i] in present) print "  " DIM e_text[_i] R
}
