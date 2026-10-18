import React from "react";
import { Easing, Img, interpolate, staticFile } from "remotion";

export const FONT = '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif';
export const MONO = '"SF Mono", ui-monospace, Menlo, monospace';
export const ACCENT = "#007AFF";
export const PRIMARY = "#1d1d1f";
export const SECONDARY = "rgba(60,60,67,0.62)";
export const QUATERNARY = "rgba(0,0,0,0.06)";
export const BRAND = ["#8f5cfa", "#4a54f2", "#1f6bed"];

/** Eased interpolation over keyframes, clamped at both ends. */
export const kf = (frame: number, input: number[], output: number[], easing = Easing.inOut(Easing.cubic)) =>
  interpolate(frame, input, output, { easing, extrapolateLeft: "clamp", extrapolateRight: "clamp" });

export const icon = (name: string) => staticFile(`${name}.png`);

// MARK: Blink glyph

/** The Blink mark, drawn the way BlinkGlyph.swift draws it, with each part's draw-in progress. */
export const Glyph: React.FC<{
  size: number;
  color?: string;
  stem?: number;
  branches?: number;
  chosen?: number;
  dim?: number;
}> = ({ size, color = "white", stem = 1, branches = 1, chosen = 1, dim = 0.45 }) => {
  const branch = (d: string, p: number, opacity: number, end: [number, number]) => (
    <g opacity={opacity}>
      <path d={d} pathLength={1} strokeDasharray={1} strokeDashoffset={1 - p} fill="none" stroke={color} strokeWidth={10} strokeLinecap="round" />
      <circle cx={end[0]} cy={end[1]} r={8.5 * Math.min(1, p * 1.6 - 0.6 > 0 ? p * 1.6 - 0.6 : 0)} fill={color} />
    </g>
  );
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" style={{ overflow: "visible" }}>
      {branch("M42 50 L86 50", branches, dim, [86, 50])}
      {branch("M42 50 C62 50 62 84 86 84", branches, dim, [86, 84])}
      {branch("M42 50 C62 50 62 16 86 16", chosen, 1, [86, 16])}
      <path d="M14 50 L42 50" pathLength={1} strokeDasharray={1} strokeDashoffset={1 - stem} stroke={color} strokeWidth={10} strokeLinecap="round" />
      <circle cx={14} cy={50} r={10.6 * Math.min(1, stem * 3)} fill={color} />
    </svg>
  );
};

/** The app icon, rebuilt so the glyph can draw itself in. */
export const AppIcon: React.FC<{ size: number; stem?: number; branches?: number; chosen?: number }> = ({ size, ...glyph }) => (
  <div
    style={{
      width: size,
      height: size,
      borderRadius: size * 0.225,
      background: `linear-gradient(160deg, ${BRAND[0]} 0%, ${BRAND[1]} 55%, ${BRAND[2]} 100%)`,
      boxShadow: `0 ${size * 0.08}px ${size * 0.25}px rgba(60,40,200,0.45), inset 0 0 0 ${size * 0.006}px rgba(255,255,255,0.35)`,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
    }}
  >
    <div style={{ filter: `drop-shadow(0 ${size * 0.015}px ${size * 0.02}px rgba(0,0,40,0.25))` }}>
      <Glyph size={size * 0.62} {...glyph} />
    </div>
  </div>
);

// MARK: Picker

export type Row = { icon?: string; name: string; profile?: boolean; shortcut?: number; profiles?: boolean; expanded?: boolean };

const KeyCap: React.FC<{ k: string; tint?: "neutral" | "accent" | "onAccent" }> = ({ k, tint = "neutral" }) => {
  const style = {
    neutral: { color: SECONDARY, background: QUATERNARY },
    accent: { color: ACCENT, background: "rgba(0,122,255,0.15)" },
    onAccent: { color: "rgba(255,255,255,0.92)", background: "rgba(255,255,255,0.22)" },
  }[tint];
  return (
    <span
      style={{
        ...style,
        minWidth: 18,
        height: 18,
        padding: k.length > 1 ? "0 4px" : 0,
        borderRadius: 5,
        fontSize: 10.5,
        fontWeight: 500,
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        boxSizing: "border-box",
        fontVariantNumeric: "tabular-nums",
      }}
    >
      {k}
    </span>
  );
};

const Chevron: React.FC<{ rotate: number }> = ({ rotate }) => (
  <span style={{ width: 22, height: 22, display: "inline-flex", alignItems: "center", justifyContent: "center" }}>
    <svg width={8} height={11} viewBox="0 0 8 11" style={{ transform: `rotate(${rotate}deg)` }}>
      <path d="M2 1.5 L6 5.5 L2 9.5" fill="none" stroke={SECONDARY} strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  </span>
);

const Divider = () => <div style={{ height: 0.5, background: "rgba(0,0,0,0.12)" }} />;

const LinkSymbol = () => (
  <svg width={14} height={14} viewBox="0 0 24 24" fill="none" stroke={SECONDARY} strokeWidth={2.4} strokeLinecap="round">
    <path d="M10 14a4.5 4.5 0 0 0 6.4 0l3-3a4.5 4.5 0 0 0-6.4-6.4l-1.2 1.2" />
    <path d="M14 10a4.5 4.5 0 0 0-6.4 0l-3 3a4.5 4.5 0 0 0 6.4 6.4l1.2-1.2" />
  </svg>
);

export const Checkbox: React.FC<{ checked: number }> = ({ checked }) => (
  <span
    style={{
      width: 14,
      height: 14,
      borderRadius: 4,
      boxSizing: "border-box",
      border: checked > 0.5 ? "none" : "0.5px solid rgba(0,0,0,0.25)",
      background: checked > 0.5 ? ACCENT : "white",
      boxShadow: "0 0.5px 1px rgba(0,0,0,0.15)",
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      flexShrink: 0,
    }}
  >
    <svg width={10} height={10} viewBox="0 0 10 10">
      <path d="M2 5.2 L4.2 7.3 L8 2.8" pathLength={1} strokeDasharray={1} strokeDashoffset={1 - checked} fill="none" stroke="white" strokeWidth={1.7} strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  </span>
);

const Capsule: React.FC<{ children: React.ReactNode; prominent?: boolean }> = ({ children, prominent }) => (
  <span
    style={{
      height: 28,
      padding: "0 8px 0 12px",
      borderRadius: 14,
      display: "inline-flex",
      alignItems: "center",
      gap: 6,
      fontSize: 12.5,
      fontWeight: 600,
      color: prominent ? "white" : PRIMARY,
      background: prominent ? ACCENT : "rgba(255,255,255,0.7)",
      boxShadow: prominent
        ? "inset 0 0.5px 0 rgba(255,255,255,0.4), 0 1px 3px rgba(0,60,160,0.3)"
        : "inset 0 0 0 0.5px rgba(0,0,0,0.08), 0 1px 3px rgba(0,0,0,0.08)",
    }}
  >
    {children}
  </span>
);

/**
 * The picker, laid out like PickerView.swift with Liquid Glass. `expand` animates the profile
 * rows that follow the row marked `profiles` open, and `opening` names the row being opened.
 */
export const Picker: React.FC<{
  host: string;
  summary: string;
  rows: Row[];
  selection: number;
  expand: number;
  checked: number;
  opening?: number;
  waiting?: string;
}> = ({ host, summary, rows, selection, expand, checked, opening, waiting }) => {
  const rowHeight = 36;
  return (
    <div
      style={{
        width: 360,
        borderRadius: 22,
        overflow: "hidden",
        fontFamily: FONT,
        color: PRIMARY,
        background: "linear-gradient(180deg, #fbfbfe, #f2f2f7)",
        boxShadow:
          "0 30px 80px rgba(20,10,70,0.38), 0 8px 24px rgba(20,10,70,0.18), inset 0 0 0 0.5px rgba(255,255,255,0.8), 0 0 0 0.5px rgba(0,0,0,0.12)",
      }}
    >
      <div style={{ padding: "14px 14px 10px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <div style={{ width: 28, height: 28, borderRadius: 7, background: QUATERNARY, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <LinkSymbol />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13, fontWeight: 600, lineHeight: "16px" }}>{host}</div>
            <div style={{ fontSize: 11, color: SECONDARY, lineHeight: "14px", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{summary}</div>
          </div>
          {waiting && (
            <span style={{ fontSize: 10.5, fontWeight: 500, padding: "2px 7px", borderRadius: 10, background: QUATERNARY }}>{waiting}</span>
          )}
        </div>
        <div style={{ marginTop: 6, fontSize: 10.5, color: SECONDARY, display: "flex", alignItems: "center", gap: 4 }}>
          <svg width={7} height={8} viewBox="0 0 7 8">
            <path d="M1 0.8 L6 4 L1 7.2 Z" fill={SECONDARY} />
          </svg>
          Full link
        </div>
      </div>
      <Divider />
      <div style={{ padding: 6 }}>
        {rows.map((row, i) => {
          const h = row.profile ? rowHeight * expand : rowHeight;
          const highlighted = i === selection;
          return (
            <div
              key={row.name}
              style={{
                height: h,
                opacity: row.profile ? kf(expand, [0.4, 1], [0, 1]) : 1,
                overflow: "hidden",
                borderRadius: 12,
                background: highlighted ? "rgba(0,122,255,0.2)" : "transparent",
                display: "flex",
                alignItems: "center",
                gap: 10,
                padding: "0 8px",
                fontSize: 13,
              }}
            >
              {row.profile ? <span style={{ width: 24 }} /> : <Img src={icon(row.icon!)} style={{ width: 24, height: 24 }} />}
              <span style={{ flex: 1, fontSize: row.profile ? 12.5 : 13 }}>{row.name}</span>
              {opening === i ? (
                <span style={{ fontSize: 10.5, color: SECONDARY }}>Opening…</span>
              ) : (
                <>
                  {row.profiles && <Chevron rotate={row.expanded ? 90 * expand : 0} />}
                  {row.shortcut && <KeyCap k={`${row.shortcut}`} tint={highlighted ? "accent" : "neutral"} />}
                </>
              )}
            </div>
          );
        })}
      </div>
      <Divider />
      <div style={{ padding: "9px 14px", display: "flex", alignItems: "center", gap: 7, fontSize: 12 }}>
        <Checkbox checked={checked} />
        Always open {host} in the chosen browser
      </div>
      <div style={{ padding: "4px 12px 12px", display: "flex", alignItems: "center", gap: 8 }}>
        <Capsule>
          Copy <KeyCap k="⌘C" />
        </Capsule>
        <span style={{ flex: 1 }} />
        <Capsule>
          Cancel <KeyCap k="esc" />
        </Capsule>
        <Capsule prominent>
          Open <KeyCap k="↩" tint="onAccent" />
        </Capsule>
      </div>
    </div>
  );
};

// MARK: Desktop pieces

export const TrafficLights = () => (
  <div style={{ display: "flex", gap: 8 }}>
    {["#ff5f57", "#febc2e", "#28c840"].map((c) => (
      <span key={c} style={{ width: 12, height: 12, borderRadius: 6, background: c, boxShadow: "inset 0 0 0 0.5px rgba(0,0,0,0.15)" }} />
    ))}
  </div>
);

export const Window: React.FC<{ x: number; y: number; w: number; h: number; style?: React.CSSProperties; children: React.ReactNode }> = ({
  x,
  y,
  w,
  h,
  style,
  children,
}) => (
  <div
    style={{
      position: "absolute",
      left: x,
      top: y,
      width: w,
      height: h,
      borderRadius: 16,
      overflow: "hidden",
      background: "white",
      fontFamily: FONT,
      color: PRIMARY,
      boxShadow: "0 24px 70px rgba(20,10,70,0.35), 0 0 0 0.5px rgba(0,0,0,0.2)",
      ...style,
    }}
  >
    {children}
  </div>
);

export const Cursor: React.FC<{ x: number; y: number; press?: number; opacity?: number }> = ({ x, y, press = 0, opacity = 1 }) => (
  <div style={{ position: "absolute", left: x, top: y, opacity, pointerEvents: "none" }}>
    {press > 0 && (
      <div
        style={{
          position: "absolute",
          left: -22,
          top: -22,
          width: 44,
          height: 44,
          borderRadius: 22,
          border: "2px solid rgba(255,255,255,0.9)",
          background: "rgba(0,122,255,0.25)",
          transform: `scale(${0.4 + press * 0.8})`,
          opacity: 1 - press,
        }}
      />
    )}
    <svg width={17} height={24} viewBox="0 0 17 24" style={{ transform: `scale(${1 - 0.12 * Math.sin(Math.PI * Math.min(1, press * 2))})`, transformOrigin: "0 0", filter: "drop-shadow(0 1px 1.5px rgba(0,0,0,0.35))" }}>
      <path d="M1 1 L1 18.5 L5.3 14.4 L8.3 21.6 L11.3 20.4 L8.4 13.3 L14.3 13.3 Z" fill="black" stroke="white" strokeWidth={1.4} strokeLinejoin="round" />
    </svg>
  </div>
);

export const Bubble: React.FC<{ children: React.ReactNode; link?: boolean; style?: React.CSSProperties }> = ({ children, link, style }) => (
  <div
    style={{
      position: "absolute",
      left: 16,
      padding: "8px 13px",
      borderRadius: 17,
      background: "#e9e9eb",
      fontSize: 13,
      lineHeight: "18px",
      maxWidth: 330,
      color: link ? "#0a66d6" : PRIMARY,
      textDecoration: link ? "underline" : "none",
      textUnderlineOffset: 2,
      transformOrigin: "0 100%",
      ...style,
    }}
  >
    {children}
  </div>
);

/** A browser window, with the browser's icon and profile shown beside the address field. */
export const BrowserWindow: React.FC<{
  x: number;
  y: number;
  browserIcon: string;
  profile: string;
  url: string;
  title: string;
  style?: React.CSSProperties;
}> = ({ x, y, browserIcon, profile, url, title, style }) => (
  <Window x={x} y={y} w={640} h={470} style={style}>
    <div style={{ height: 46, background: "#f4f4f6", borderBottom: "0.5px solid rgba(0,0,0,0.1)", display: "flex", alignItems: "center", gap: 14, padding: "0 14px" }}>
      <TrafficLights />
      <Img src={icon(browserIcon)} style={{ width: 22, height: 22 }} />
      <div style={{ flex: 1, height: 28, borderRadius: 14, background: "white", boxShadow: "inset 0 0 0 0.5px rgba(0,0,0,0.12)", display: "flex", alignItems: "center", gap: 7, padding: "0 12px", fontSize: 12.5 }}>
        <svg width={9} height={11} viewBox="0 0 9 11">
          <rect x={0.5} y={4.5} width={8} height={6} rx={1.5} fill={SECONDARY} />
          <path d="M2.3 4.8 V3.2 a2.2 2.2 0 0 1 4.4 0 V4.8" fill="none" stroke={SECONDARY} strokeWidth={1.2} />
        </svg>
        <span style={{ color: SECONDARY }}>https://</span>
        <span style={{ marginLeft: -7 }}>{url}</span>
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 6, padding: "4px 10px 4px 4px", borderRadius: 14, background: "rgba(0,122,255,0.12)", fontSize: 12, fontWeight: 600, color: ACCENT }}>
        <span style={{ width: 20, height: 20, borderRadius: 10, background: ACCENT, color: "white", fontSize: 10, display: "flex", alignItems: "center", justifyContent: "center" }}>
          {profile[0]}
        </span>
        {profile}
      </div>
    </div>
    <div style={{ padding: "26px 30px" }}>
      <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: -0.3 }}>{title}</div>
      <div style={{ marginTop: 10, display: "flex", gap: 8, alignItems: "center" }}>
        <span style={{ padding: "3px 10px", borderRadius: 12, background: "#1f883d", color: "white", fontSize: 11.5, fontWeight: 600 }}>Open</span>
        <span style={{ fontSize: 12, color: SECONDARY }}>marek-e wants to merge 9 commits into main</span>
      </div>
      <div style={{ marginTop: 22, height: 0.5, background: "rgba(0,0,0,0.1)" }} />
      {[0.92, 0.78, 0.86, 0.6, 0.0, 0.88, 0.7, 0.8].map((w, i) => (
        <div key={i} style={{ marginTop: 14, height: w ? 10 : 6, width: `${w * 100}%`, borderRadius: 5, background: "rgba(0,0,0,0.07)" }} />
      ))}
    </div>
  </Window>
);
