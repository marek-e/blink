import React, { createContext, useContext } from "react";
import { AbsoluteFill, Easing, Img, Sequence, spring, useCurrentFrame, useVideoConfig } from "remotion";
import {
  ACCENT,
  AppIcon,
  BRAND,
  BrowserWindow,
  Bubble,
  Checkbox,
  Cursor,
  FONT,
  Glyph,
  icon,
  kf,
  Picker,
  PRIMARY,
  Row,
  SECONDARY,
  TrafficLights,
  Window,
} from "./ui";

/** Scene starts, in frames at 30 fps. Neighbouring scenes overlap to crossfade. */
const HOOK = { from: 0, length: 134 };
const LOGO = { from: 122, length: 88 };
/** The demo is timed in script frames and plays at `DEMO_SPEED`, so its captions have time to read. */
const DEMO_SCRIPT = 460;
const DEMO_SPEED = 0.85;
const DEMO = { from: 198, length: Math.ceil(DEMO_SCRIPT / DEMO_SPEED) };
const RULES = { from: 732, length: 140 };
const FEATURES = { from: 864, length: 135 };
const OUTRO = { from: 991, length: 140 };
export const TOTAL = OUTRO.from + OUTRO.length;

/** Demo scenes lay the desktop out in points and scale it to the 1920×1080 frame. */
const UNIT = 1920 / 1097;

const Speed = createContext(1);
const useFrame = () => useCurrentFrame() * useContext(Speed);

const fadeInOut = (f: number, length: number, fade = 12) => kf(f, [0, fade, length - fade, length], [0, 1, 1, 0]);

export const Launch: React.FC = () => (
  <AbsoluteFill style={{ background: "#07060f", fontFamily: FONT }}>
    <Sequence from={HOOK.from} durationInFrames={HOOK.length}>
      <Hook />
    </Sequence>
    <Sequence from={LOGO.from} durationInFrames={LOGO.length}>
      <Logo />
    </Sequence>
    <Sequence from={DEMO.from} durationInFrames={DEMO.length}>
      <Speed.Provider value={DEMO_SPEED}>
        <Demo />
      </Speed.Provider>
    </Sequence>
    <Sequence from={RULES.from} durationInFrames={RULES.length}>
      <Rules />
    </Sequence>
    <Sequence from={FEATURES.from} durationInFrames={FEATURES.length}>
      <Features />
    </Sequence>
    <Sequence from={OUTRO.from} durationInFrames={OUTRO.length}>
      <Outro />
    </Sequence>
  </AbsoluteFill>
);

// MARK: Shared pieces

const DarkStage: React.FC<{ children: React.ReactNode; opacity?: number }> = ({ children, opacity = 1 }) => (
  <AbsoluteFill
    style={{
      opacity,
      background: `radial-gradient(1100px 700px at 30% 20%, rgba(143,92,250,0.35), transparent 70%),
        radial-gradient(1000px 700px at 80% 90%, rgba(31,107,237,0.35), transparent 70%), #07060f`,
      color: "white",
      fontFamily: FONT,
    }}
  >
    {children}
  </AbsoluteFill>
);

const Wallpaper: React.FC = () => (
  <AbsoluteFill
    style={{
      background: `radial-gradient(900px 650px at 15% 10%, ${BRAND[0]}, transparent 70%),
        radial-gradient(1000px 800px at 90% 95%, ${BRAND[2]}, transparent 70%),
        radial-gradient(800px 600px at 70% 30%, #b56cf0, transparent 70%),
        linear-gradient(140deg, #5b3fd6, #3a49d8 50%, #2457d6)`,
    }}
  />
);

const MenuBar: React.FC = () => (
  <div
    style={{
      position: "absolute",
      left: 0,
      top: 0,
      right: 0,
      height: 24,
      background: "rgba(255,255,255,0.18)",
      backdropFilter: "blur(20px)",
      display: "flex",
      alignItems: "center",
      justifyContent: "flex-end",
      gap: 16,
      padding: "0 14px",
      color: "white",
      fontSize: 12.5,
      fontWeight: 500,
    }}
  >
    <Glyph size={16} />
    <span>Mon 9:41</span>
  </div>
);

/** A step title on the left of the frame, over a scrim so it reads on the wallpaper. */
const Caption: React.FC<{ step?: string; title: string; sub?: string; from: number; to: number }> = ({ step, title, sub, from, to }) => {
  const f = useFrame();
  if (f < from - 1 || f > to + 1) return null;
  const opacity = kf(f, [from, from + 8, to - 6, to], [0, 1, 1, 0]);
  const y = kf(f, [from, from + 10], [24, 0], Easing.out(Easing.cubic));
  return (
    <div style={{ position: "absolute", left: 120, top: 380, width: 640, opacity, transform: `translateY(${y}px)`, color: "white" }}>
      {step && (
        <div
          style={{
            width: 56,
            height: 56,
            borderRadius: 28,
            background: "rgba(255,255,255,0.18)",
            boxShadow: "inset 0 0 0 1.5px rgba(255,255,255,0.5)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontSize: 28,
            fontWeight: 700,
            marginBottom: 26,
          }}
        >
          {step}
        </div>
      )}
      <div style={{ fontSize: 76, fontWeight: 700, letterSpacing: -1.5, lineHeight: 1.04, textShadow: "0 4px 30px rgba(20,0,80,0.35)" }}>{title}</div>
      {sub && <div style={{ marginTop: 20, fontSize: 34, lineHeight: 1.3, fontWeight: 500, color: "rgba(255,255,255,0.82)" }}>{sub}</div>}
    </div>
  );
};

/** A big keycap that pops up while a key is pressed. */
const KeyPress: React.FC<{ k: string; at: number; x?: number }> = ({ k, at, x = 120 }) => {
  const f = useFrame();
  const { fps } = useVideoConfig();
  if (f < at - 8 || f > at + 22) return null;
  const pop = spring({ frame: f - (at - 8), fps, config: { damping: 14, stiffness: 220 } });
  const down = kf(f, [at - 1, at, at + 4], [0, 1, 0]);
  const opacity = kf(f, [at + 14, at + 22], [1, 0]);
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: 820,
        width: 120,
        height: 120,
        borderRadius: 26,
        opacity,
        transform: `scale(${pop * (1 - 0.08 * down)}) translateY(${down * 6}px)`,
        background: down > 0.3 ? ACCENT : "rgba(255,255,255,0.95)",
        color: down > 0.3 ? "white" : PRIMARY,
        boxShadow: `0 ${12 - down * 8}px 0 rgba(20,10,70,0.25), 0 20px 50px rgba(20,10,70,0.35)`,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontSize: k.length > 1 ? 40 : 60,
        fontWeight: 600,
      }}
    >
      {k}
    </div>
  );
};

// MARK: Hook

const HOOK_ICONS = ["arc", "dia", "chrome", "zen", "safari"];

const Hook: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const dimmed = kf(f, [50, 60, 82, 88], [0, 1, 1, 0]);
  const gather = kf(f, [112, 130], [0, 1], Easing.in(Easing.cubic));
  const lines = [
    { text: "You have five browsers.", from: 0, to: 46 },
    { text: "macOS lets you pick one.", from: 46, to: 82 },
    { text: "Blink lets you pick for every link.", from: 82, to: 134 },
  ];
  return (
    <DarkStage opacity={kf(f, [0, 6], [0, 1])}>
      {lines.map(({ text, from, to }) =>
        f >= from && f < to ? (
          <div
            key={text}
            style={{
              position: "absolute",
              top: 330,
              width: "100%",
              textAlign: "center",
              fontSize: 92,
              fontWeight: 700,
              letterSpacing: -2,
              opacity: kf(f, [from, from + 6, to - 4, to], [0, 1, 1, from === 82 ? 1 : 0]),
              transform: `translateY(${kf(f, [from, from + 8], [20, 0], Easing.out(Easing.cubic))}px)`,
            }}
          >
            {text}
          </div>
        ) : null,
      )}
      {HOOK_ICONS.map((name, i) => {
        const pop = spring({ frame: f - 4 - i * 4, fps, config: { damping: 12, stiffness: 160 } });
        const x0 = 960 + (i - 2) * 250;
        const isDefault = name === "safari";
        const x = x0 + (960 - x0) * gather;
        return (
          <Img
            key={name}
            src={icon(name)}
            style={{
              position: "absolute",
              left: x - 100,
              top: 560,
              width: 200,
              height: 200,
              transform: `scale(${pop * (1 - 0.6 * gather) * (isDefault ? 1 + 0.08 * dimmed : 1 - 0.12 * dimmed)})`,
              opacity: (isDefault ? 1 : 1 - 0.75 * dimmed) * (1 - gather),
              filter: isDefault ? "none" : `grayscale(${dimmed})`,
            }}
          />
        );
      })}
    </DarkStage>
  );
};

// MARK: Logo

const Logo: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame: f - 4, fps, config: { damping: 13, stiffness: 120 } });
  const out = kf(f, [72, 88], [0, 1], Easing.in(Easing.cubic));
  const word = kf(f, [26, 40], [0, 1], Easing.out(Easing.cubic));
  const tag = kf(f, [36, 50], [0, 1], Easing.out(Easing.cubic));
  return (
    <DarkStage opacity={kf(f, [0, 8], [0, 1]) * (1 - out)}>
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", transform: `scale(${1 + out * 0.08})` }}>
        <div style={{ transform: `scale(${0.6 + 0.4 * pop})`, opacity: Math.min(1, pop * 1.5) }}>
          <AppIcon size={280} stem={kf(f, [8, 18], [0, 1])} branches={kf(f, [16, 30], [0, 1])} chosen={kf(f, [16, 30], [0, 1])} />
        </div>
        <div style={{ marginTop: 50, fontSize: 150, fontWeight: 800, letterSpacing: -5, opacity: word, transform: `translateY(${(1 - word) * 30}px)` }}>Blink</div>
        <div style={{ marginTop: 6, fontSize: 46, fontWeight: 500, color: "rgba(255,255,255,0.75)", opacity: tag, transform: `translateY(${(1 - tag) * 20}px)` }}>
          From link to browser, instantly.
        </div>
      </AbsoluteFill>
    </DarkStage>
  );
};

// MARK: Demo

const PICKER = { x: 446, y: 140 };
const LINK1 = { x: 820, y: 250 };
const LINK2 = { x: 820, y: 336 };
const CHECKBOX = { x: 469, y: 491 };
const FOCUS = { x: PICKER.x + 180, y: PICKER.y + 206 };

const ROWS: Row[] = [
  { icon: "arc", name: "Arc", shortcut: 1, profiles: true },
  { icon: "dia", name: "Dia", shortcut: 2 },
  { icon: "chrome", name: "Google Chrome", shortcut: 3, profiles: true, expanded: true },
  { name: "Work", profile: true },
  { name: "Personal", profile: true },
  { icon: "zen", name: "Zen", shortcut: 4 },
  { icon: "safari", name: "Safari", shortcut: 5 },
];

/** Positions the desktop so that `zoom` (0 to 1) moves the camera onto the picker. */
const camera = (zoom: number) => {
  const z = UNIT * (1 + 0.2 * zoom);
  const focus = { x: 548.5 + (FOCUS.x - 548.5) * zoom, y: 308.5 + (FOCUS.y - 308.5) * zoom };
  const screen = { x: 960 + (1240 - 960) * zoom, y: 540 };
  return `translate(${screen.x - focus.x * z}px, ${screen.y - focus.y * z}px) scale(${z})`;
};

const along = (f: number, frames: number[], points: { x: number; y: number }[]) => ({
  x: kf(f, frames, points.map((p) => p.x)),
  y: kf(f, frames, points.map((p) => p.y)),
});

const Demo: React.FC = () => {
  const f = useFrame();
  const { fps } = useVideoConfig();

  const zoom = kf(f, [54, 82, 250, 280], [0, 1, 1, 0]);
  const selection = f < 96 ? 0 : f < 112 ? 1 : f < 160 ? 2 : 3;
  const expand = kf(f, [135, 147], [0, 1], Easing.out(Easing.cubic));
  const checked = kf(f, [209, 217], [0, 1]);
  const pickerIn = spring({ frame: f - 48, fps, config: { damping: 15, stiffness: 200 } });
  const pickerOut = kf(f, [252, 260], [0, 1]);

  const cursor = along(f, [6, 40, 182, 204, 352, 378], [{ x: 1010, y: 470 }, LINK1, LINK1, CHECKBOX, CHECKBOX, LINK2]);
  const press = Math.max(kf(f, [44, 58], [0, 1]), kf(f, [208, 222], [0, 1]), kf(f, [382, 396], [0, 1]));
  const pressing = (start: number) => f >= start && f <= start + 14;

  const firstWindow = spring({ frame: f - 262, fps, config: { damping: 16, stiffness: 140 } });
  const firstWindowOut = kf(f, [332, 340], [0, 1], Easing.in(Easing.cubic));
  const secondWindow = spring({ frame: f - 394, fps, config: { damping: 16, stiffness: 160 } });
  const streak = kf(f, [384, 396], [0, 1], Easing.out(Easing.cubic));

  const bubbleIn = (at: number) => spring({ frame: f - at, fps, config: { damping: 14, stiffness: 200 } });

  return (
    <AbsoluteFill style={{ opacity: kf(f, [0, 14, DEMO_SCRIPT - 10, DEMO_SCRIPT], [0, 1, 1, 0]) }}>
      <div style={{ position: "absolute", width: 1097, height: 617, transformOrigin: "0 0", transform: camera(zoom) }}>
        <Wallpaper />
        <MenuBar />

        <Window x={640} y={110} w={420} h={420}>
          <div style={{ height: 56, borderBottom: "0.5px solid rgba(0,0,0,0.1)", display: "flex", alignItems: "center", gap: 14, padding: "0 16px" }}>
            <TrafficLights />
            <div style={{ width: 32, height: 32, borderRadius: 16, background: "linear-gradient(160deg,#f7a35c,#e8566c)", color: "white", fontSize: 13, fontWeight: 600, display: "flex", alignItems: "center", justifyContent: "center" }}>
              SR
            </div>
            <div>
              <div style={{ fontSize: 13, fontWeight: 600 }}>Sam Rivera</div>
              <div style={{ fontSize: 11, color: SECONDARY }}>Active now</div>
            </div>
          </div>
          <Bubble style={{ top: 76 }}>Can you check the profiles PR before standup?</Bubble>
          <Bubble link style={{ top: 122 }}>
            https://github.com/marek-e/blink/pull/4
          </Bubble>
          {f > 344 && <Bubble style={{ top: 172, transform: `scale(${bubbleIn(344)})` }}>And this bug:</Bubble>}
          {f > 352 && (
            <Bubble link style={{ top: 209, transform: `scale(${bubbleIn(352)})` }}>
              https://github.com/marek-e/blink/issues/7
            </Bubble>
          )}
          <div style={{ position: "absolute", left: 16, right: 16, bottom: 14, height: 30, borderRadius: 15, boxShadow: "inset 0 0 0 0.5px rgba(0,0,0,0.2)", fontSize: 12.5, color: "rgba(60,60,67,0.4)", display: "flex", alignItems: "center", padding: "0 12px" }}>
            Message
          </div>
        </Window>

        {f >= 262 && f < 341 && (
          <BrowserWindow
            x={440}
            y={66}
            browserIcon="chrome"
            profile="Work"
            url="github.com/marek-e/blink/pull/4"
            title="Show browser profiles in the picker #4"
            style={{
              opacity: kf(f, [262, 266], [0, 1]) * (1 - firstWindowOut),
              transform: `translateY(${(1 - firstWindow) * 60 + firstWindowOut * 30}px) scale(${(0.92 + 0.08 * firstWindow) * (1 - 0.04 * firstWindowOut)})`,
            }}
          />
        )}

        {f >= 384 && f < 400 && (
          <svg style={{ position: "absolute", left: 0, top: 0, overflow: "visible" }} width={1097} height={617}>
            <path
              d={`M${LINK2.x} ${LINK2.y} C ${LINK2.x + 120} ${LINK2.y} 840 90 720 90`}
              pathLength={1}
              strokeDasharray={1}
              strokeDashoffset={1 - streak}
              fill="none"
              stroke="white"
              strokeWidth={5}
              strokeLinecap="round"
              opacity={kf(f, [392, 400], [1, 0])}
              style={{ filter: "drop-shadow(0 0 8px rgba(255,255,255,0.9))" }}
            />
          </svg>
        )}

        {f >= 394 && (
          <BrowserWindow
            x={440}
            y={66}
            browserIcon="chrome"
            profile="Work"
            url="github.com/marek-e/blink/issues/7"
            title="Picker opens on the wrong display #7"
            style={{ opacity: kf(f, [394, 398], [0, 1]), transform: `translateY(${(1 - secondWindow) * 50}px) scale(${0.9 + 0.1 * secondWindow})` }}
          />
        )}

        {f >= 48 && f < 261 && (
          <div
            style={{
              position: "absolute",
              left: PICKER.x,
              top: PICKER.y,
              transformOrigin: "100% 25%",
              transform: `scale(${(0.85 + 0.15 * pickerIn) * (1 - 0.04 * pickerOut)})`,
              opacity: Math.min(1, pickerIn * 2) * (1 - pickerOut),
            }}
          >
            <Picker
              host="github.com"
              summary="https://github.com/marek-e/blink/pull/4"
              rows={ROWS}
              selection={selection}
              expand={expand}
              checked={checked}
              opening={f >= 238 ? 3 : undefined}
            />
          </div>
        )}

        <Cursor x={cursor.x} y={cursor.y} press={pressing(44) || pressing(208) || pressing(382) ? press : 0} opacity={kf(f, [4, 8], [0, 1])} />
      </div>

      <AbsoluteFill style={{ background: "linear-gradient(90deg, rgba(15,5,50,0.55), rgba(15,5,50,0.25) 40%, transparent 55%)" }} />

      <Caption step="1" title="Click a link anywhere" sub="Blink is your default browser, so every link comes to it first." from={4} to={48} />
      <Caption step="2" title="Pick a browser" sub="Press 1 to 9, use the arrow keys, or click." from={50} to={126} />
      <Caption step="3" title="Or a profile" sub="→ shows a browser's profiles." from={126} to={180} />
      <Caption step="4" title="Make it a rule" sub="Tick the box and github.com always opens here." from={180} to={230} />
      <Caption step="5" title="Press Return" from={230} to={262} />
      <Caption title="Opened in Chrome" sub="In your Work profile." from={262} to={336} />
      <Caption title="Next time, no picker" sub="The rule sends github.com straight to Chrome · Work." from={340} to={DEMO_SCRIPT} />

      <KeyPress k="↓" at={96} />
      <KeyPress k="↓" at={112} x={260} />
      <KeyPress k="→" at={135} />
      <KeyPress k="↓" at={160} x={260} />
      <KeyPress k="↩" at={236} />
    </AbsoluteFill>
  );
};

// MARK: Rules

const RULE_ROWS = [
  { domain: "github.com", scope: "This domain only", icon: "chrome", to: "Google Chrome · Work" },
  { domain: "figma.com", scope: "This domain and its subdomains", icon: "arc", to: "Arc · Design" },
  { domain: "docs.google.com", scope: "This domain only", icon: "dia", to: "Dia · Personal" },
  { domain: "localhost", scope: "This domain only", icon: "zen", to: "Zen" },
];

const Switch = () => (
  <span style={{ width: 26, height: 15, borderRadius: 8, background: "#34c759", position: "relative", flexShrink: 0 }}>
    <span style={{ position: "absolute", right: 1.5, top: 1.5, width: 12, height: 12, borderRadius: 6, background: "white", boxShadow: "0 1px 2px rgba(0,0,0,0.25)" }} />
  </span>
);

const TabIcon: React.FC<{ label: string; active?: boolean; children: React.ReactNode }> = ({ label, active, children }) => (
  <div
    style={{
      width: 68,
      height: 48,
      borderRadius: 10,
      background: active ? "rgba(0,0,0,0.07)" : "transparent",
      color: active ? ACCENT : SECONDARY,
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      gap: 3,
      fontSize: 11,
    }}
  >
    <svg width={20} height={18} viewBox="0 0 20 18" fill="none" stroke="currentColor" strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round">
      {children}
    </svg>
    {label}
  </div>
);

const Rules: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const win = spring({ frame: f - 4, fps, config: { damping: 16, stiffness: 150 } });
  const typed = "https://www.figma.com/file/launch";
  const chars = Math.round(kf(f, [46, 78], [0, typed.length], Easing.linear));
  return (
    <AbsoluteFill style={{ opacity: fadeInOut(f, RULES.length, 10) }}>
      <div style={{ position: "absolute", width: 1097, height: 617, transformOrigin: "0 0", transform: `scale(${UNIT})` }}>
        <Wallpaper />
        <MenuBar />
        <Window
          x={470}
          y={92}
          w={580}
          h={440}
          style={{ background: "#f6f6f8", opacity: Math.min(1, win * 2), transform: `translateY(${(1 - win) * 40}px) scale(${0.94 + 0.06 * win})` }}
        >
          <div style={{ padding: "12px 16px 8px", display: "flex", alignItems: "flex-start" }}>
            <TrafficLights />
            <div style={{ flex: 1, display: "flex", justifyContent: "center", gap: 4, marginLeft: -52, marginTop: 14 }}>
              <TabIcon label="General">
                <circle cx={10} cy={9} r={3} />
                <path d="M10 1.5v2.5M10 14v2.5M2.5 9H5M15 9h2.5M4.7 3.7l1.8 1.8M13.5 12.5l1.8 1.8M4.7 14.3l1.8-1.8M13.5 5.5l1.8-1.8" />
              </TabIcon>
              <TabIcon label="Browsers">
                <circle cx={10} cy={9} r={7.5} />
                <path d="M12.8 6.2 L8.6 7.6 L7.2 11.8 L11.4 10.4 Z" />
              </TabIcon>
              <TabIcon label="Rules" active>
                <path d="M2 9h5M7 9c3 0 3-6 7-6M7 9c3 0 3 6 7 6M14 3h3M14 15h3" />
              </TabIcon>
            </div>
          </div>
          <div style={{ padding: "6px 22px 0", fontSize: 12, color: SECONDARY, lineHeight: "16px" }}>
            Links that match a rule open without asking. The first matching rule wins, so put specific rules above broad ones.
          </div>
          <div style={{ margin: "12px 22px 0", borderRadius: 10, background: "white", boxShadow: "inset 0 0 0 0.5px rgba(0,0,0,0.12)", overflow: "hidden" }}>
            {RULE_ROWS.map((rule, i) => {
              const p = kf(f, [12 + i * 6, 24 + i * 6], [0, 1], Easing.out(Easing.cubic));
              return (
                <div
                  key={rule.domain}
                  style={{
                    height: 50,
                    display: "flex",
                    alignItems: "center",
                    gap: 12,
                    padding: "0 14px",
                    borderTop: i ? "0.5px solid rgba(0,0,0,0.08)" : "none",
                    opacity: p,
                    transform: `translateX(${(1 - p) * 30}px)`,
                    background: i === 1 && f > 84 ? "rgba(0,122,255,0.1)" : "transparent",
                  }}
                >
                  <Switch />
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 13, fontWeight: 600 }}>{rule.domain}</div>
                    <div style={{ fontSize: 11, color: SECONDARY }}>{rule.scope}</div>
                  </div>
                  <Img src={icon(rule.icon)} style={{ width: 20, height: 20 }} />
                  <span style={{ fontSize: 12.5 }}>{rule.to}</span>
                </div>
              );
            })}
          </div>
          <div style={{ margin: "8px 22px 0", display: "flex", gap: 6, fontSize: 13, color: PRIMARY }}>
            {["+", "−"].map((s) => (
              <span key={s} style={{ width: 24, height: 20, borderRadius: 5, background: "white", boxShadow: "inset 0 0 0 0.5px rgba(0,0,0,0.15)", display: "flex", alignItems: "center", justifyContent: "center" }}>
                {s}
              </span>
            ))}
          </div>
          <div style={{ margin: "16px 22px 0", fontSize: 12, fontWeight: 600 }}>Test a link</div>
          <div
            style={{
              margin: "6px 22px 0",
              height: 24,
              borderRadius: 6,
              background: "white",
              boxShadow: f > 40 ? `0 0 0 3px rgba(0,122,255,0.3), inset 0 0 0 0.5px ${ACCENT}` : "inset 0 0 0 0.5px rgba(0,0,0,0.2)",
              fontSize: 12.5,
              display: "flex",
              alignItems: "center",
              padding: "0 8px",
              color: chars ? PRIMARY : "rgba(60,60,67,0.35)",
            }}
          >
            {chars ? typed.slice(0, chars) : "https://example.com/page"}
            {f > 40 && f < 84 && Math.floor(f / 8) % 2 === 0 && <span style={{ width: 1, height: 14, background: PRIMARY, marginLeft: 1 }} />}
          </div>
          <div style={{ margin: "6px 22px 0", fontSize: 11.5, color: SECONDARY, opacity: kf(f, [84, 92], [0, 1]) }}>
            Opens in Arc · Design using the rule for figma.com.
          </div>
        </Window>
      </div>
      <AbsoluteFill style={{ background: "linear-gradient(90deg, rgba(15,5,50,0.55), rgba(15,5,50,0.25) 40%, transparent 55%)" }} />
      <Caption title="Rules live in Settings" sub="The first match wins. Paste a link to see where it goes." from={4} to={RULES.length} />
    </AbsoluteFill>
  );
};

// MARK: Features

const Features: React.FC = () => {
  const f = useCurrentFrame();
  const items: { visual: React.ReactNode; text: string }[] = [
    {
      visual: (
        <div style={{ display: "flex" }}>
          {["arc", "dia", "chrome", "zen"].map((n, i) => (
            <Img key={n} src={icon(n)} style={{ width: 64, height: 64, marginLeft: i ? -18 : 0 }} />
          ))}
        </div>
      ),
      text: "Profiles in Arc, Dia, Chrome, Brave, Edge, Vivaldi, Zen, Firefox",
    },
    {
      visual: <span style={{ fontSize: 24, fontWeight: 600, padding: "8px 16px", borderRadius: 30, background: "rgba(255,255,255,0.16)" }}>3 more links</span>,
      text: "Links that arrive together wait their turn",
    },
    {
      visual: (
        <svg width={60} height={56} viewBox="0 0 24 22">
          <path d="M12 1.5 L23 20.5 H1 Z" fill="#ff9f0a" stroke="#ff9f0a" strokeWidth={1.5} strokeLinejoin="round" />
          <path d="M12 8v6" stroke="#1d1d1f" strokeWidth={2.2} strokeLinecap="round" />
          <circle cx={12} cy={17.3} r={1.3} fill="#1d1d1f" />
        </svg>
      ),
      text: "A browser fails? Blink keeps the link and asks you",
    },
    {
      visual: (
        <svg width={56} height={60} viewBox="0 0 22 24" fill="none" stroke="white" strokeWidth={2} strokeLinejoin="round">
          <rect x={3} y={10} width={16} height={12} rx={3} fill="white" />
          <path d="M6.5 10V7a4.5 4.5 0 0 1 9 0v3" />
        </svg>
      ),
      text: "No history, no network requests, no URLs in logs",
    },
  ];
  return (
    <DarkStage opacity={fadeInOut(f, FEATURES.length, 10)}>
      <div style={{ position: "absolute", left: 150, top: 200 }}>
        {items.map(({ visual, text }, i) => {
          const p = kf(f, [6 + i * 12, 20 + i * 12], [0, 1], Easing.out(Easing.cubic));
          return (
            <div key={text} style={{ height: 170, display: "flex", alignItems: "center", gap: 44, opacity: p, transform: `translateY(${(1 - p) * 30}px)` }}>
              <div style={{ width: 210, display: "flex", justifyContent: "center" }}>{visual}</div>
              <div style={{ fontSize: 48, fontWeight: 650, letterSpacing: -1 }}>{text}</div>
            </div>
          );
        })}
      </div>
    </DarkStage>
  );
};

// MARK: Outro

const Outro: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame: f - 2, fps, config: { damping: 14, stiffness: 130 } });
  const text = (at: number) => kf(f, [at, at + 14], [0, 1], Easing.out(Easing.cubic));
  return (
    <DarkStage opacity={kf(f, [0, 10], [0, 1])}>
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
        <div style={{ transform: `scale(${0.7 + 0.3 * pop})` }}>
          <AppIcon size={220} stem={kf(f, [4, 12], [0, 1])} branches={kf(f, [10, 22], [0, 1])} chosen={kf(f, [10, 22], [0, 1])} />
        </div>
        <div style={{ marginTop: 40, fontSize: 120, fontWeight: 800, letterSpacing: -4, opacity: text(12) }}>Blink</div>
        <div style={{ fontSize: 40, fontWeight: 500, color: "rgba(255,255,255,0.75)", opacity: text(20) }}>Free and open source, for macOS 14 and later.</div>
        <div
          style={{
            marginTop: 56,
            padding: "22px 40px",
            borderRadius: 60,
            background: "white",
            color: PRIMARY,
            fontSize: 44,
            fontWeight: 700,
            letterSpacing: -0.5,
            display: "flex",
            alignItems: "center",
            gap: 18,
            opacity: text(30),
            transform: `translateY(${(1 - text(30)) * 20}px)`,
            boxShadow: "0 20px 60px rgba(80,60,240,0.45)",
          }}
        >
          <Glyph size={44} color={BRAND[1]} />
          github.com/marek-e/blink
        </div>
      </AbsoluteFill>
    </DarkStage>
  );
};
