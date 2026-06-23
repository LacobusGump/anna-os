# Anna Interaction Rules

## Three modes

| Mode | Trigger | Output | Voice? |
|------|---------|--------|--------|
| **Calibrating** | Always (default) | Watch face: question + Yes/No | **Never** |
| **Conversing** | "Hey Anna" | Two-way talk | **Yes** |
| **Alerting** | Anna decides it matters | e.g. "Jim, this person is lying to you." | **Yes** |

## Why calibration is silent

Spoken guess questions create a fake voice in your head — same failure mode as bad assistants. Calibration is **eyes + tap**. Learn without narration.

## Persistent listening

One always-on ear:
1. Every 2s → guess → show top prompt on face (if calibrating)
2. Continuous → listen for "Hey Anna"

No button to "start listening." It's already on.

## Voice is gated

`speak()` only when `InteractionMode.maySpeak == true`.

Questions, confidence %, sensor readouts → never TTS.